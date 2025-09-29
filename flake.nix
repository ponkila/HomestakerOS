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
    devenv.url = "github:cachix/devenv/v1.9";
    ethereum-nix.url = "github:nix-community/ethereum.nix";
    flake-parts.url = "github:hercules-ci/flake-parts";
    git-hooks-nix.inputs.nixpkgs.follows = "nixpkgs";
    git-hooks-nix.url = "github:cachix/git-hooks.nix";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    ponkila.url = "github:ponkila/HomestakerOS?dir=nixosModules/base";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs = { self, ... }@inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {

    systems = inputs.nixpkgs.lib.systems.flakeExposed;
    imports = [
      inputs.devenv.flakeModule
      inputs.flake-parts.flakeModules.easyOverlay
      inputs.git-hooks-nix.flakeModule
      inputs.treefmt-nix.flakeModule
    ];

    perSystem = { config, pkgs, system, ... }: {
      # Custom packages and entrypoint aliases -> 'nix run' or 'nix build'
      packages = rec {
        # Ethereum.nix
        "besu" = inputs.ethereum-nix.packages.${system}.besu;
        "erigon" = inputs.ethereum-nix.packages.${system}.erigon;
        "geth" = inputs.ethereum-nix.packages.${system}.geth;
        "lighthouse" = inputs.ethereum-nix.packages.${system}.lighthouse;
        "mev-boost" = inputs.ethereum-nix.packages.${system}.mev-boost;
        "nethermind" = inputs.ethereum-nix.packages.${system}.nethermind;
        "nimbus" = inputs.ethereum-nix.packages.${system}.nimbus;
        "prysm" = inputs.ethereum-nix.packages.${system}.prysm;
        "reth" = inputs.ethereum-nix.packages.${system}.reth;
        "ssvnode" = inputs.ethereum-nix.packages.${system}.ssvnode;
        "teku" = inputs.ethereum-nix.packages.${system}.teku;
        # Main
        "backend" = pkgs.callPackage ./packages/backend { inherit json2nix; };
        "default" = config.packages.backend;
        "frontend" = pkgs.callPackage ./webui { };
        "homestakeros-backend" = self.nixosConfigurations.homestakeros-backend.config.system.build.kexecTree;
        "init-ssv" = pkgs.callPackage ./packages/init-ssv { inherit ssvnode; };
        "json2nix" = pkgs.callPackage ./packages/json2nix { };
        "update-json" = pkgs.callPackage ./packages/update-json { };
      };

      # Overlays
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [
          self.overlays.default
        ];
        config = { };
      };
      overlayAttrs = config.packages;

      # Nix code formatter -> 'nix fmt'
      treefmt.config = {
        projectRootFile = "flake.nix";
        flakeFormatter = true;
        flakeCheck = true;
        programs = {
          deadnix.enable = true;
          nixpkgs-fmt.enable = true;
          statix.enable = true;
        };
      };

      # Development shell -> 'nix develop' or 'direnv allow'
      devenv.shells.default = {
        packages = with pkgs; [
          cargo-tarpaulin
          jq
          nodePackages.eslint
          nodejs
          typescript
          yarn
          yarn2nix
          # Cargo test deps
          json2nix
          nix
        ];
        languages.rust.enable = true;
        env.NIX_CONFIG = ''
          accept-flake-config = true
          extra-experimental-features = flakes nix-command
          warn-dirty = false
        '';
        git-hooks = {
          hooks = {
            cargo-check.enable = true;
            clippy.enable = true;
            deadnix.enable = true;
            nixpkgs-fmt.enable = true;
            rustfmt.enable = true;
            shellcheck.enable = true;
            statix = {
              enable = true;
              settings.config = ''
                disabled = [
                  "repeated_keys"
                ]
              '';
            };
          };
          settings.rust.cargoManifestPath = "./packages/backend/Cargo.toml";
        };
        # Workaround for https://github.com/cachix/devenv/issues/760
        containers = inputs.nixpkgs.lib.mkForce { };
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
