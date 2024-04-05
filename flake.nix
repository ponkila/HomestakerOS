{
  inputs = {
    devenv.url = "github:cachix/devenv";
    flake-parts.url = "github:hercules-ci/flake-parts";
    homestakeros.url = "github:ponkila/HomestakerOS\?dir=modules/homestakeros";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-parts,
    homestakeros,
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
        inputs.devenv.flakeModule
      ];

      perSystem = {
        pkgs,
        lib,
        config,
        self',
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

        devenv.shells = {
          default = {
            packages = with pkgs; [
              self'.packages.init-ssv
              nodejs
              jq
              yarn
              yarn2nix
            ];
            scripts.server.exec = ''
              nix eval --no-warn-dirty --json .#schema | jq > webui/public/schema.json \
              && yarn install && yarn build \
              && nix run --no-warn-dirty .#update-json \
              && nix run --no-warn-dirty .#
            '';
            env = {
              NIX_CONFIG = ''
                accept-flake-config = true
                extra-experimental-features = flakes nix-command
                warn-dirty = false
              '';
            };
            enterShell = ''
              cat <<INFO

              ### HomestakerOS ###

              Available commands:

                server    : Initialize and launch the web server
                init-ssv  : Generate an SSV operator key pair

              INFO
            '';
            pre-commit.hooks = {
              alejandra.enable = true;
              shellcheck.enable = true;
            };
            # Workaround for https://github.com/cachix/devenv/issues/760
            containers = pkgs.lib.mkForce {};
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
              homestakeros.inputs.ethereum-nix.packages."x86_64-linux".ssvnode
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
        system = "x86_64-linux";
      in {
        nixosConfigurations = let
          ls = builtins.readDir ./nixosConfigurations;
          hostnames =
            builtins.filter
            (name: builtins.hasAttr name ls && (ls.${name} == "directory"))
            (builtins.attrNames ls);
        in
          nixpkgs.lib.mkIf (
            builtins.pathExists ./nixosConfigurations
          ) (
            builtins.listToAttrs (map (hostname: {
                name = hostname;
                value = nixpkgs.lib.nixosSystem {
                  inherit system;
                  specialArgs = {inherit inputs outputs;};
                  modules = [
                    self.nixosModules.kexecTree
                    homestakeros.nixosModules.homestakeros
                    ./nixosConfigurations/${hostname}
                    {
                      system.stateVersion = "23.05";
                      # Bootloader for x86_64-linux / aarch64-linux
                      boot.loader.systemd-boot.enable = true;
                      boot.loader.efi.canTouchEfiVariables = true;
                    }
                  ];
                };
              })
              hostnames)
          );

        schema = homestakeros.outputs.exports.homestakeros;

        # Format modules
        nixosModules.isoImage = {
          imports = [./modules/copytoram-iso.nix];
        };
        nixosModules.kexecTree = {
          imports = [./modules/netboot-kexec.nix];
        };
      };
    };
}
