{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-root.url = "github:srid/flake-root";
    mission-control.url = "github:Platonic-Systems/mission-control";
    nixobolus.url = "github:ponkila/nixobolus";
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

        devShells = {
          default = pkgs.mkShell {
            nativeBuildInputs = with pkgs; [
              nodejs
              just
            ];
            inputsFrom = [
              config.flake-root.devShell
              config.mission-control.devShell
            ];
          };
        };

        packages.homestakeros = pkgs.buildNpmPackage {
          pname = "homestakeros-ui";
          version = "0.0.1";

          src = ./.;
          npmDepsHash = "sha256-5aCtzyfSnDn+i2gmhkx9HU/BRb5ZSc3wacJgx4OF+8U=";

          # The prepack script runs the build script, which we'd rather do in the build phase.
          # npmPackFlags = [ "--ignore-scripts" ];
          dontNpmBuild = true;

        };

        packages.default = packages.homestakeros;

      };

      flake =
        let
          inherit (self) outputs;
        in
        {

          schema = nixobolus.outputs.exports;

        };


    };

}
