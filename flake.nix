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
    ponkila.url = "github:ponkila/HomestakerOS?dir=nixosModules/base";
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
          # Function to create a basic shell script package
          # https://www.ertt.ca/nix/shell-scripts/#org6f67de6
          mkScriptPackage = { name, deps, ... }:
            let
              pkgs = import nixpkgs { inherit system; };
              scriptPath = ./scripts/${name}.sh;
              script = (pkgs.writeScriptBin name (builtins.readFile scriptPath)).overrideAttrs (old: {
                buildCommand = "${old.buildCommand}\n patchShebangs $out";
              });
            in
            pkgs.symlinkJoin {
              inherit name;
              paths = [ script ] ++ deps;
              buildInputs = [ pkgs.makeWrapper ];
              postBuild = "wrapProgram $out/bin/${name} --prefix PATH : $out/bin";
            };
        in
        rec {

          # Overlays
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [
              self.overlays.default
            ];
            config = { };
          };
          overlayAttrs = {
            inherit
              (config.packages)
              blutgang
              erigon
              lighthouse
              nethermind
              nimbus
              prysm
              reth
              ssvnode
              teku
              ;
          };

          formatter = nixpkgs.legacyPackages.${system}.nixpkgs-fmt;

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
                nixpkgs-fmt.enable = true;
                shellcheck.enable = true;
              };
              # Workaround for https://github.com/cachix/devenv/issues/760
              containers = pkgs.lib.mkForce { };
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
              deps = [ pkgs.nix ];
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
                inputs.ethereum-nix.packages.${system}.ssvnode
              ];
            };
            "update-json" = mkScriptPackage {
              name = "update-json";
              deps = [
                pkgs.nix
                pkgs.jq
              ];

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

          schema = self.exports.homestakeros;

          # Format modules
          nixosModules = {
            homestakeros = {
              imports = [
                ./nixosModules/homestakeros
              ];
            };
          };

          # Module option exports for the frontend
          # Accessible through 'nix eval --json .#exports'
          exports = parseOpts (getOpts [
            ./nixosModules/homestakeros/options.nix
          ]);
        };
    };
}
