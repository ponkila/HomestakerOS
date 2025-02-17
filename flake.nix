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
    devenv.url = "github:cachix/devenv";
    ethereum-nix.url = "github:nix-community/ethereum.nix";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    ponkila.url = "github:ponkila/HomestakerOS?dir=nixosModules/base";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs = { self, ... }@inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
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
            "frontend" = pkgs.callPackage ./webui { };
            "default" = packages.backend;
          };
        in
        {
          # Custom packages and entrypoint aliases -> 'nix run' or 'nix build'
          inherit packages;

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
                init-ssv
                jq
                nodePackages.eslint
                nodejs
                typescript
                yarn
                yarn2nix
              ];
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

                  init-ssv  : Generate an SSV operator key pair

                INFO
              '';
              pre-commit = {
                hooks = {
                  nixpkgs-fmt.enable = true;
                  shellcheck.enable = true;
                  rustfmt.enable = true;
                };
                settings.rust.cargoManifestPath = "./packages/backend/Cargo.toml";
              };
              # Workaround for https://github.com/cachix/devenv/issues/760
              containers = pkgs.lib.mkForce { };
            };
          };
        };

      flake =
        let

          # Function to format module options
          parseOpts = options:
            inputs.nixpkgs.lib.attrsets.mapAttrsRecursiveCond (v: ! inputs.nixpkgs.lib.options.isOption v)
              (_k: v: {
                type = v.type.name;
                inherit (v) default;
                description =
                  v.description or null;
                example =
                  v.example or null;
              })
              options;

          # Function to get options from module(s)
          getOpts = modules:
            builtins.removeAttrs
              (inputs.nixpkgs.lib.evalModules {
                inherit modules;
                specialArgs = { inherit (inputs) nixpkgs; };
              }).options [ "_module" ];

        in
        {
          # Format modules
          nixosModules = {
            homestakeros.imports = [
              ./nixosModules/homestakeros
            ];
            backend = {
              imports = [ ./nixosModules/backend ];
              nixpkgs.overlays = [ self.overlays.default ];
            };
          };
          schema = self.exports.homestakeros;

          # Module option exports for the frontend
          # Accessible through 'nix eval --json .#exports'
          exports = parseOpts (getOpts [
            ./nixosModules/homestakeros/options.nix
          ]);
        };
    };
}
