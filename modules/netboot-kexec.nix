{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  # No bootloader
  boot.loader.grub.enable = false;

  # These kmodules are implicit requirements of netboot
  boot.initrd.availableKernelModules = ["squashfs" "overlay" "btrfs"];
  boot.initrd.kernelModules = ["loop" "overlay"];

  fileSystems."/" = lib.mkImageMediaOverride {
    fsType = "tmpfs";
    options = ["mode=0755"];
  };

  # In stage 1, mount a tmpfs on top of /nix/store (the squashfs
  # image) to make this a live CD.
  fileSystems."/nix/.ro-store" = lib.mkImageMediaOverride {
    fsType = "squashfs";
    device = "../nix-store.squashfs";
    options = ["loop"];
    neededForBoot = true;
  };

  fileSystems."/nix/.rw-store" = lib.mkImageMediaOverride {
    fsType = "tmpfs";
    options = ["mode=0755"];
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
    storeContents = [config.system.build.toplevel];
    comp = "zstd -Xcompression-level 2";
  };

  # Create the initrd
  system.build.netbootRamdisk = pkgs.makeInitrdNG {
    compressor = "zstd";
    prepend = ["${config.system.build.initialRamdisk}/initrd"];
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
}
