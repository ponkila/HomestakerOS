{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-root.url = "github:srid/flake-root";
    mission-control.url = "github:Platonic-Systems/mission-control";
    nixobolus.url = "github:ponkila/nixobolus";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-parts,
    nixobolus,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      imports = [
        inputs.flake-root.flakeModule
        inputs.mission-control.flakeModule
      ];

      perSystem = {
        pkgs,
        lib,
        config,
        inputs',
        system,
        ...
      }: let
        # Function to create a basic shell script package
        # https://www.ertt.ca/nix/shell-scripts/#org6f67de6
        mkScriptPackage = {
          name,
          deps,
        }: let
          pkgs = import nixpkgs {inherit system;};
          scriptPath = ./scripts/${name}.sh;
          script = (pkgs.writeScriptBin name (builtins.readFile scriptPath)).overrideAttrs (old: {
            buildCommand = "${old.buildCommand}\n patchShebangs $out";
          });
        in
          pkgs.symlinkJoin {
            inherit name;
            paths = [script] ++ deps;
            buildInputs = [pkgs.makeWrapper];
            postBuild = "wrapProgram $out/bin/${name} --prefix PATH : $out/bin";
          };
      in rec {
        formatter = nixpkgs.legacyPackages.${system}.alejandra;

        mission-control.scripts = {
          server = {
            description = "Initialize and launch the web server";
            exec = ''
              nix eval --no-warn-dirty --json .#schema | jq > webui/public/schema.json \
              && yarn install && yarn build \
              && nix run --no-warn-dirty .#update-json \
              && nix run --no-warn-dirty .#
            '';
            category = "Essentials";
          };
        };

        devShells = {
          default = pkgs.mkShell {
            nativeBuildInputs = with pkgs; [
              nodejs
              jq
              yarn
              yarn2nix
            ];
            inputsFrom = [
              config.flake-root.devShell
              config.mission-control.devShell
            ];
          };
        };

        apps = {
          json2nix = {
            type = "app";
            program = "${self.packages.${system}.json2nix}/bin/json2nix";
          };
          buidl = {
            type = "app";
            program = "${self.packages.${system}.buidl}/bin/buidl";
          };
          init-ssv = {
            type = "app";
            program = "${self.packages.${system}.init-ssv}/bin/init-ssv";
          };
          update-json = {
            type = "app";
            program = "${self.packages.${system}.update-json}/bin/update-json";
          };
        };

        packages = {
          "json2nix" = mkScriptPackage {
            name = "json2nix";
            deps = [pkgs.nix];
          };
          "buidl" = mkScriptPackage {
            name = "buidl";
            deps = [
              pkgs.nix
              pkgs.jq
              pkgs.git
              self.packages.${system}.json2nix
              self.packages.${system}.update-json
            ];
          };
          "init-ssv" = mkScriptPackage {
            name = "init-ssv";
            deps = [
              pkgs.jq
              nixobolus.inputs.ethereum-nix.packages."x86_64-linux".ssvnode
            ];
          };
          "update-json" = mkScriptPackage {
            name = "update-json";
            deps = [
              pkgs.nix
              pkgs.jq
            ];
          };

          homestakeros = pkgs.mkYarnPackage {
            pname = "homestakeros";
            version = "0.0.1";

            src = ./.;
            packageJSON = ./package.json;
            yarnLock = ./yarn.lock;
            yarnNix = ./yarn.nix;
          };
          default = packages.homestakeros;
        };
      };

      flake = let
        inherit (self) outputs;
      in {
        nixosConfigurations = let
          # Fetch hostnames from nixosConfigurations directory
          ls = builtins.readDir ./nixosConfigurations;
          hostnames =
            builtins.filter
            (name: builtins.hasAttr name ls && (ls.${name} == "directory"))
            (builtins.attrNames ls);

          # Define available system architectures and formats
          formats = ["kexecTree" "isoImage"];
          systems = ["x86_64-linux" "aarch64-linux" "rpi4-linux"];

          # Generate list of attribute sets for each possible host
          hosts = builtins.concatMap (hostname:
            builtins.concatMap (format:
              builtins.map (system: {
                name = hostname;
                format = format;
                system = system;
              })
              systems)
            formats)
          hostnames;
        in
          nixpkgs.lib.mkIf (
            builtins.pathExists ./nixosConfigurations
          ) (
            builtins.listToAttrs (map (host: {
                name = "${host.name}-${host.system}-${host.format}";
                value = nixpkgs.lib.nixosSystem {
                  system =
                    if host.system == "rpi4-linux"
                    then "aarch64-linux"
                    else host.system;
                  specialArgs = {inherit inputs outputs;};
                  modules = [
                    nixobolus.nixosModules.${host.format}
                    nixobolus.nixosModules.homestakeros
                    ./nixosConfigurations/${host.name}
                    {
                      system.stateVersion = "23.05";
                    }
                    # Format spesific configurations
                    (
                      if host.format == "isoImage" && host.system != "rpi4-linux"
                      then
                        {pkgs, ...}: {
                          # Use stable kernel
                          boot.kernelPackages = pkgs.linuxPackagesFor (pkgs.linux);
                        }
                      else {}
                    )
                    # System spesific configurations
                    (
                      if host.system == "rpi4-linux"
                      then
                        {pkgs, ...}: {
                          boot.initrd.availableKernelModules = ["xhci_pci" "usbhid" "usb_storage"];
                          boot.loader = {
                            grub.enable = false;
                            generic-extlinux-compatible.enable = true;
                          };
                          # Use the Raspberry Pi 4 kernel
                          boot.kernelPackages = pkgs.linuxKernel.packages.linux_rpi4;
                        }
                      else if host.system == "aarch64-linux" || host.system == "x86_64-linux"
                      then {
                        # Bootloader for x86_64-linux / aarch64-linux
                        boot.loader.systemd-boot.enable = true;
                        boot.loader.efi.canTouchEfiVariables = true;
                      }
                      else {}
                    )
                  ];
                };
              })
              hosts)
          );

        schema = nixobolus.outputs.exports.homestakeros;
      };
    };
}
