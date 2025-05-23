{

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://devenv.cachix.org"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    besu-hotfix.url = "github:nix-community/ethereum.nix?ref=pull/607/head";
    lighthouse-hotfix.url = "github:/NixOS/nixpkgs?ref=pull/402444/head";

    devenv.url = "github:cachix/devenv";
    ethereum-nix.url = "github:nix-community/ethereum.nix";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    ponkila.url = "github:ponkila/HomestakerOS?dir=nixosModules/base";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs = { self, ... }@inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } rec {
      systems = inputs.nixpkgs.lib.systems.flakeExposed;
      imports = [
        inputs.devenv.flakeModule
        inputs.flake-parts.flakeModules.easyOverlay
        inputs.treefmt-nix.flakeModule
      ];

      perSystem =
        { pkgs
        , system
        , ...
        }:
        let
          packages = rec {
            "init-ssv" = pkgs.callPackage ./packages/init-ssv { inherit ssvnode; };
            "json2nix" = pkgs.callPackage ./packages/json2nix { };
            "update-json" = pkgs.callPackage ./packages/update-json { };
            # Ethereum.nix
            "besu" = inputs.besu-hotfix.packages.${system}.besu;
            "erigon" = inputs.ethereum-nix.packages.${system}.erigon;
            "geth" = inputs.ethereum-nix.packages.${system}.geth;
            "lighthouse" = inputs.lighthouse-hotfix.legacyPackages.${system}.lighthouse;
            "mev-boost" = inputs.nixpkgs-unstable.legacyPackages.${system}.mev-boost;
            "nethermind" = inputs.ethereum-nix.packages.${system}.nethermind;
            "nimbus" = inputs.ethereum-nix.packages.${system}.nimbus;
            "prysm" = inputs.ethereum-nix.packages.${system}.prysm;
            "reth" = inputs.ethereum-nix.packages.${system}.reth;
            "ssvnode" = inputs.ethereum-nix.packages.${system}.ssvnode;
            "teku" = inputs.ethereum-nix.packages.${system}.teku;
            # Main
            "backend" = pkgs.callPackage ./packages/backend { inherit json2nix; };
            "frontend" = pkgs.callPackage ./webui { };
            "default" = packages.backend;
          };
        in
        {
          # Custom packages and entrypoint aliases -> 'nix run' or 'nix build'
          packages =
            (with flake.nixosConfigurations; {
              "homestakeros-backend" = homestakeros-backend.config.system.build.kexecTree;
            })
            // packages;

          # Overlays
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [
              self.overlays.default
            ];
            config = { };
          };
          overlayAttrs = packages;

          # Nix code formatter -> 'nix fmt'
          treefmt.config = {
            projectRootFile = "flake.nix";
            flakeFormatter = true;
            flakeCheck = true;
            programs = {
              nixpkgs-fmt.enable = true;
              deadnix.enable = true;
              statix.enable = true;
              rustfmt.enable = true;
            };
            settings.global.excludes = [ "*/flake.nix" ];
          };

          # Development shell -> 'nix develop' or 'direnv allow'
          devenv.shells = {
            default = {
              packages = with pkgs; [
                jq
                nodePackages.eslint
                nodejs
                typescript
                yarn
                yarn2nix
                cargo-tarpaulin
                # Cargo test deps
                nix
                json2nix
              ];
              languages.rust = {
                enable = true;
                components = [ "cargo" "clippy" ];
              };
              env = {
                NIX_CONFIG = ''
                  accept-flake-config = true
                  extra-experimental-features = flakes nix-command
                  warn-dirty = false
                '';
              };
              pre-commit =
                let
                  cargoTomlPath = "./packages/backend/Cargo.toml";
                in
                {
                  hooks =
                    {
                      nixpkgs-fmt.enable = true;
                      shellcheck.enable = true;
                      rustfmt.enable = true;
                      pedantic-clippy = {
                        enable = true;
                        entry = "cargo clippy --manifest-path ${cargoTomlPath} -- -D clippy::pedantic";
                        files = "\\.rs$";
                        pass_filenames = false;
                      };
                      cargo-test = {
                        enable = true;
                        entry = "cargo test --manifest-path ${cargoTomlPath} --all-features";
                        files = "\\.rs$";
                        pass_filenames = false;
                      };
                    };
                  settings.rust.cargoManifestPath = cargoTomlPath;
                };
              # Workaround for https://github.com/cachix/devenv/issues/760
              containers = pkgs.lib.mkForce { };
            };
          };
        };

      flake =
        let
          introspect = import ./introspect.nix { inherit (self.inputs.nixpkgs) lib; };

          # Function to get options from module(s)
          getOpts = modules:
            builtins.removeAttrs
              (inputs.nixpkgs.lib.evalModules {
                inherit modules;
                specialArgs = { inherit (inputs) nixpkgs; };
              }).options [ "_module" ];
        in
        {
          # NixOS configuration entrypoints
          nixosConfigurations."homestakeros-backend" = inputs.nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = { inherit inputs; };
            modules = [
              inputs.ponkila.nixosModules.base
              inputs.ponkila.nixosModules.kexecTree
              self.nixosModules.backend
              self.nixosModules.homestakeros
              {
                homestakeros = {
                  localization = {
                    hostname = "homestakeros-backend";
                    timezone = "Europe/Helsinki";
                  };
                  ssh = {
                    authorizedKeys = [
                      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAILn/9IHTGC1sLxnPnLbtJpvF7HgXQ8xNkRwSLq8ay8eJAAAADHNzaDpzdGFybGFicw== ssh:starlabs"
                      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOdsfK46X5IhxxEy81am6A8YnHo2rcF2qZ75cHOKG7ToAAAACHNzaDprYXJp ssh:kari"
                    ];
                  };
                };
                services.homestakeros-backend = {
                  enable = true;
                  reverseProxy = "nginx";
                };
                fileSystems."/mnt/ubuntu-root" = {
                  device = "/dev/disk/by-uuid/17974942-c81d-4bc4-898c-792f95be67ec";
                  fsType = "ext4";
                  neededForBoot = true;
                };
                systemd.services.nix-remount = {
                  path = [ "/run/wrappers" ];
                  enable = true;
                  description = "Mount /nix/.rw-store and /tmp to disk";
                  serviceConfig = {
                    Type = "oneshot";
                  };
                  preStart = ''
                    /run/wrappers/bin/mount -t none /mnt/ubuntu-root/remount /nix/.rw-store -o bind

                    mkdir -p /nix/.rw-store/work
                    mkdir -p /nix/.rw-store/store
                    mkdir -p /nix/.rw-store/tmp
                    chmod 1777 /nix/.rw-store/tmp
                  '';
                  script = ''
                    /run/wrappers/bin/mount -t overlay overlay -o lowerdir=/nix/.ro-store:/nix/store,upperdir=/nix/.rw-store/store,workdir=/nix/.rw-store/work /nix/store
                    /run/wrappers/bin/mount --bind /nix/.rw-store/tmp /tmp
                  '';
                  wantedBy = [ "multi-user.target" ];
                };
                system.stateVersion = "24.11";
              }
            ];
          };

          # Format modules
          nixosModules = {
            homestakeros = {
              imports = [ ./nixosModules/homestakeros ];
              nixpkgs.overlays = [ self.overlays.default ];
            };
            backend = {
              imports = [ ./nixosModules/backend ];
              nixpkgs.overlays = [ self.overlays.default ];
            };
          };
          schema = self.exports.homestakeros;

          # Module option exports for the frontend
          # Accessible through 'nix eval --json .#exports'
          exports = introspect.parseOpts (getOpts [
            ./nixosModules/homestakeros/options.nix
          ]);
        };
    };
}
