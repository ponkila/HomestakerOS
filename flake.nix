{

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    devenv.url = "github:cachix/devenv";
    ethereum-nix.url = "github:nix-community/ethereum.nix";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-23.05";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    ponkila.inputs.nixpkgs.follows = "nixpkgs";
    ponkila.url = "github:ponkila/HomestakerOS/jesse/mv-module-here?dir=nixosModules/base";
  };

  outputs =
    inputs @ { self
    , devenv
    , ethereum-nix
    , flake-parts
    , nixpkgs-stable
    , nixpkgs
    , ponkila
    , ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [
        inputs.devenv.flakeModule
        inputs.flake-parts.flakeModules.easyOverlay
      ];

      perSystem =
        { pkgs
        , lib
        , config
        , self'
        , inputs'
        , system
        , ...
        }:
        let
          packages = rec {
            "buidl" = pkgs.callPackage ./packages/buidl { inherit json2nix update-json; };
            "init-ssv" = pkgs.callPackage ./packages/init-ssv { inherit ssvnode; };
            "json2nix" = pkgs.callPackage ./packages/json2nix { };
            "update-json" = pkgs.callPackage ./packages/update-json { };
            # Ethereum.nix
            "blutgang" = inputs.ethereum-nix.packages.${system}.blutgang;
            "erigon" = inputs.ethereum-nix.packages.${system}.erigon;
            "lighthouse" = inputs.ethereum-nix.packages.${system}.lighthouse;
            "nethermind" = inputs.ethereum-nix.packages.${system}.nethermind;
            "nimbus" = inputs.ethereum-nix.packages.${system}.nimbus;
            "prysm" = inputs.ethereum-nix.packages.${system}.prysm;
            "reth" = inputs.ethereum-nix.packages.${system}.reth;
            "ssvnode" = inputs.ethereum-nix.packages.${system}.ssvnode;
            "teku" = inputs.ethereum-nix.packages.${system}.teku;
            "mev-boost" = inputs.ethereum-nix.packages.${system}.mev-boost;
            # Main
            "homestakeros" = pkgs.mkYarnPackage {
              pname = "homestakeros";
              version = "0.0.1";

              src = ./.;
              packageJSON = ./package.json;
              yarnLock = ./yarn.lock;
              yarnNix = ./yarn.nix;
            };
            "default" = packages.homestakeros;
          };
        in
        {
          # Custom packages
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

          formatter = nixpkgs.legacyPackages.${system}.nixpkgs-fmt;

          devenv.shells = {
            default = {
              packages = with pkgs; [
                init-ssv
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
                nixpkgs-fmt.enable = true;
                shellcheck.enable = true;
              };
              # Workaround for https://github.com/cachix/devenv/issues/760
              containers = pkgs.lib.mkForce { };
            };
          };
        };

      flake =
        let
          inherit (self) outputs;

          # Function to format module options
          parseOpts = options:
            nixpkgs.lib.attrsets.mapAttrsRecursiveCond (v: ! nixpkgs.lib.options.isOption v)
              (k: v: {
                type = v.type.name;
                default = v.default;
                description =
                  if v ? description
                  then v.description
                  else null;
                example =
                  if v ? example
                  then v.example
                  else null;
              })
              options;

          # Function to get options from module(s)
          getOpts = modules:
            builtins.removeAttrs
              (nixpkgs.lib.evalModules {
                inherit modules;
                specialArgs = { inherit nixpkgs; };
              }).options [ "_module" ];

        in
        {
          nixosConfigurations =
            let
              ls = builtins.readDir ./nixosConfigurations;
              hostnames =
                builtins.filter
                  (name: builtins.hasAttr name ls && (ls.${name} == "directory"))
                  (builtins.attrNames ls);
            in
            nixpkgs.lib.mkIf
              (
                builtins.pathExists ./nixosConfigurations
              )
              (
                builtins.listToAttrs (map
                  (hostname: {
                    name = hostname;
                    value = nixpkgs.lib.nixosSystem {
                      system = "x86_64-linux";
                      specialArgs = { inherit inputs outputs; };
                      modules = [
                        ponkila.nixosModules.kexecTree
                        self.nixosModules.homestakeros
                        ./nixosConfigurations/${hostname}
                        {
                          system.stateVersion = "23.05";
                        }
                      ];
                    };
                  })
                  hostnames)
              );

          # Module option schema for the frontend
          # Accessible through 'nix eval --json .#schema'
          schema = parseOpts (getOpts [
            ./nixosModules/homestakeros/options.nix
          ]);

          # Format modules
          nixosModules = {
            homestakeros = {
              imports = [
                ./nixosModules/homestakeros
              ];
            };
          };

        };
    };
}
