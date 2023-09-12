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
                  modules =
                    [
                      nixobolus.nixosModules.kexecTree
                      nixobolus.nixosModules.homestakeros
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

        schema = nixobolus.outputs.exports.homestakeros;
      };
    };
}
