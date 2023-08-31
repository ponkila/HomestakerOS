{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-root.url = "github:srid/flake-root";
    frontend.url = "github:ponkila/HomestakerOS/feat/pkgs-webui?dir=packages/frontend";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-parts,
    frontend,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        #"aarch64-darwin"
        #"aarch64-linux"
        #"x86_64-darwin"
        "x86_64-linux"
      ];
      imports = [
        inputs.flake-root.flakeModule
      ];

      perSystem = {
        pkgs,
        lib,
        config,
        self',
        inputs',
        system,
        ...
      }: {
        formatter = nixpkgs.legacyPackages.${system}.alejandra;

        packages.homestakeros = let
          pname = "homestakeros";
          version = "0.0.1";
          src = ./.;
        in
          pkgs.mkYarnPackage {
            inherit pname version src;

            packageJSON = ./package.json;
            yarnLock = ./yarn.lock;

            prePatch = ''
              substituteInPlace ./app.js \
                --replace webui/dist ${inputs'.frontend.packages.webui}/dist
            '';
          };

        packages.default = self'.packages.homestakeros;
      };
    };
}
