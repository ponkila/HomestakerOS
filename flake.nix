{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-root.url = "github:srid/flake-root";
    mission-control.url = "github:Platonic-Systems/mission-control";
    nixobolus.url = "github:ponkila/nixobolus";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  outputs =
    inputs@{ self
    , nixpkgs
    , flake-parts
    , nixobolus
    , ...
    }:

    flake-parts.lib.mkFlake { inherit inputs; } {

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

      perSystem = { pkgs, lib, config, system, ... }: rec {

        mission-control.scripts = {
          schema = {
            description = "Update schema using current version of nixobolus";
            exec = ''
              nix eval --json .#schema | jq > webui/schema.json
            '';
            category = "Development Tools";
          };
          server = {
            description = "Initialize and launch the web server";
            exec = ''
              mkfifo webui/pipe && nix run .#
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
          buidl = {
            type = "app";
            program = nixobolus.packages.${system}.buidl;
          };
        };

        packages = {
        };

        packages.homestakeros = pkgs.mkYarnPackage {
          pname = "homestakeros-ui";
          version = "0.0.1";

          src = ./.;
          packageJSON = ./package.json;
          yarnLock = ./yarn.lock;
          yarnNix = ./yarn.nix;
        };

        packages.default = packages.homestakeros;

      };

      flake =
        let
          inherit (self) outputs;
        in
        {
          nixosConfigurations = {
            homestakeros = nixpkgs.lib.nixosSystem {
              system = "x86_64-linux";
              specialArgs = { inherit inputs outputs; };
              modules = [
                nixobolus.nixosModules.kexecTree
                nixobolus.nixosModules.homestakeros
                ./nixosConfigurations/homestakeros
                {
                  system.stateVersion = "23.05";
                  # Bootloader for x86_64-linux / aarch64-linux
                  boot.loader.systemd-boot.enable = true;
                  boot.loader.efi.canTouchEfiVariables = true;
                }
              ];
            };
          };

          schema = nixobolus.outputs.exports;

        };


    };

}
