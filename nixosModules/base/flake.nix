{
  description = "Opinionated NixOS base config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {

    # derived from https://github.com/nix-community/nixos-generators/blob/master/formats/install-iso.nix
    nixosModules.isoImage = { lib, modulesPath, ... }: {
      imports = [
        "${toString modulesPath}/installer/cd-dvd/installation-cd-base.nix"
      ];

      # for installer
      isoImage.isoName = lib.mkForce "nixos.iso";

      # override installation-cd-base and enable wpa and sshd start at boot
      #systemd.services.wpa_supplicant.wantedBy = lib.mkForce [ "multi-user.target" ];
      #systemd.services.sshd.wantedBy = lib.mkForce [ "multi-user.target" ];

      # GRUB timeout
      boot.loader.timeout = lib.mkForce 1;

      # Load into a tmpfs during stage-1
      boot.kernelParams = [ "copytoram" ];
    };

    nixosModules.kexecTree = { config, lib, pkgs, modulesPath, ... }: {
      # No bootloader
      boot.loader.grub.enable = false;

      # These kmodules are implicit requirements of netboot
      boot.initrd.availableKernelModules = [ "squashfs" "overlay" "btrfs" ];
      boot.initrd.kernelModules = [ "loop" "overlay" ];

      fileSystems."/" = lib.mkImageMediaOverride {
        fsType = "tmpfs";
        options = [ "mode=0755" ];
      };

      # In stage 1, mount a tmpfs on top of /nix/store (the squashfs
      # image) to make this a live CD.
      fileSystems."/nix/.ro-store" = lib.mkImageMediaOverride {
        fsType = "squashfs";
        device = "../nix-store.squashfs";
        options = [ "loop" ];
        neededForBoot = true;
      };

      fileSystems."/nix/.rw-store" = lib.mkImageMediaOverride {
        fsType = "tmpfs";
        options = [ "mode=0755" ];
        neededForBoot = true;
      };

      fileSystems."/nix/store" = lib.mkImageMediaOverride {
        fsType = "overlay";
        device = "overlay";
        options = [
          "lowerdir=/nix/.ro-store"
          "upperdir=/nix/.rw-store/store"
          "workdir=/nix/.rw-store/work"
        ];

        depends = [
          "/nix/.ro-store"
          "/nix/.rw-store/store"
          "/nix/.rw-store/work"
        ];
      };

      boot.postBootCommands = ''
        # After booting, register the contents of the Nix store in the Nix database in the tmpfs.
        ${config.nix.package}/bin/nix-store --load-db < /nix/store/nix-path-registration
        # nixos-rebuild also requires a "system" profile and an /etc/NIXOS tag.
        touch /etc/NIXOS
        ${config.nix.package}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system
      '';

      # Create the squashfs image that contains the Nix store.
      system.build.squashfsStore = pkgs.callPackage "${toString modulesPath}/../lib/make-squashfs.nix" {
        # Closures to be copied to the Nix store, namely the init
        # script and the top-level system configuration directory.
        storeContents = [ config.system.build.toplevel ];
        comp = "zstd -Xcompression-level 2";
      };

      # Create the initrd
      system.build.netbootRamdisk = pkgs.makeInitrdNG {
        compressor = "zstd";
        prepend = [ "${config.system.build.initialRamdisk}/initrd" ];
        contents = [
          {
            object = config.system.build.squashfsStore;
            symlink = "/nix-store.squashfs";
          }
        ];
      };

      system.build.netbootIpxeScript = pkgs.writeText "netboot.ipxe" ''
        #!ipxe
        # Use the cmdline variable to allow the user to specify custom kernel params
        # when chainloading this script from other iPXE scripts like netboot.xyz
        chain --autofree variables.ipxe
        kernel bzImage ''${kernel-params} ''${cmdline}
        initrd initrd.zst
        boot
      '';

      # variables.ipxe updates the boot stanza for the kernel, changing with
      # Flake derivation hash changes, i.e., during a git update. For the updated
      # image to boot, it must dynamically generate changes in the iPXE menu.
      system.build.netbootIpxeVariables = pkgs.writeText "variables.ipxe" ''
        #!ipxe
        set kernel-params init=${config.system.build.toplevel}/init initrd=initrd.zst ${toString config.boot.kernelParams}
      '';

      # A script invoking kexec on ./bzImage and ./initrd.zst.
      # Usually used through system.build.kexecTree, but exposed here for composability.
      system.build.kexecScript = pkgs.writeScript "kexec-boot" ''
        #!/usr/bin/env bash
        if ! kexec -v >/dev/null 2>&1; then
          echo "kexec not found: please install kexec-tools" 2>&1
          exit 1
        fi
        SCRIPT_DIR=$( cd -- "$( dirname -- "''${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
        kexec --load ''${SCRIPT_DIR}/bzImage \
          --initrd=''${SCRIPT_DIR}/initrd.zst \
          --command-line "init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams}"
        systemctl kexec
      '';

      # A tree containing initrd.zst, bzImage and a kexec-boot script.
      system.build.kexecTree = pkgs.linkFarm "kexec-tree" [
        {
          name = "initrd.zst";
          path = "${config.system.build.netbootRamdisk}/initrd";
        }
        {
          name = "bzImage";
          path = "${config.system.build.kernel}/${config.system.boot.loader.kernelFile}";
        }
        {
          name = "kexec-boot";
          path = config.system.build.kexecScript;
        }
        {
          name = "netboot.ipxe";
          path = config.system.build.netbootIpxeScript;
        }
        {
          name = "variables.ipxe";
          path = config.system.build.netbootIpxeVariables;
        }
      ];
    };

    nixosModules.base = { pkgs, config, lib, inputs, ... }: {
      nix = {
        # This will add each flake input as a registry
        # To make nix3 commands consistent with your flake
        registry = lib.mapAttrs
          (_: value: {
            flake = value;
          })
          inputs;

        # This will additionally add your inputs to the system's legacy channels
        # Making legacy nix commands consistent as well, awesome!
        nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;

        settings = {
          # Enable flakes and new 'nix' command
          experimental-features = "nix-command flakes";
          # Deduplicate and optimize nix store
          auto-optimise-store = true;

          extra-substituters = [
            "https://cache.nixos.org"
            "https://nix-community.cachix.org"
          ];
          extra-trusted-public-keys = [
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          ];

          # Allows this server to be used as a remote builder
          trusted-users = [
            "root"
            "@wheel"
          ];
        };
        package = pkgs.nix;
      };

      boot = {
        kernelParams = [
          "boot.shell_on_fail"

          "mitigations=off"
          "l1tf=off"
          "mds=off"
          "no_stf_barrier"
          "noibpb"
          "noibrs"
          "nopti"
          "nospec_store_bypass_disable"
          "nospectre_v1"
          "nospectre_v2"
          "tsx=on"
          "tsx_async_abort=off"
        ];
        # Increase tmpfs (default: "50%")
        tmp.tmpfsSize = "80%";
      };

      environment.systemPackages = with pkgs; [
        btrfs-progs
        kexec-tools
        fuse-overlayfs
        rsync
        bind
        file
        tree
        vim
      ];

      # Better clock sync via chrony
      services.timesyncd.enable = false;
      services.chrony = {
        enable = true;
        servers = [
          "ntp1.hetzner.de"
          "ntp2.hetzner.com"
          "ntp3.hetzner.net"
        ];
      };

      # Reboots hanged system
      systemd.watchdog.device = "/dev/watchdog";
      systemd.watchdog.runtimeTime = "30s";

      # Audit tracing
      security.auditd.enable = true;
      security.audit.enable = true;
      security.audit.rules = [
        "-a exit,always -F arch=b64 -S execve"
      ];

      # Rip out packages
      environment.defaultPackages = lib.mkForce [ ];
      environment.noXlibs = true;
      documentation.doc.enable = false;
      xdg.mime.enable = false;
      xdg.menus.enable = false;
      xdg.icons.enable = false;
      xdg.sounds.enable = false;
      xdg.autostart.enable = false;

      # Allow passwordless sudo from wheel group
      security.sudo = {
        enable = lib.mkDefault true;
        wheelNeedsPassword = lib.mkForce false;
        execWheelOnly = true;
      };
    };
  };
}
