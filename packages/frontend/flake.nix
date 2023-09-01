{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-root.url = "github:srid/flake-root";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
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

        packages.frontend = let
          src = ./../..;
          version = "0.0.1";
          name = "homestakeros-frontend";

          yarnOfflineCache = pkgs.fetchYarnDeps {
            yarnLock = "${src}/yarn.lock";
            hash = "sha256-mkcsTfcCFa+KBct3Btu0S10Pt+QgkZ5vrI0ets8GAxg=";
          };
        in
          pkgs.stdenv.mkDerivation {
            inherit src version name yarnOfflineCache;

            buildInputs = with pkgs; [
              nodejs_18
              yarn
              yarn2nix-moretea.fixup_yarn_lock
            ];

            configurePhase = ''
              export HOME=$(mktemp -d)
            '';

            buildPhase = ''
              yarn config --offline set yarn-offline-mirror ${yarnOfflineCache}
              fixup_yarn_lock ${src}/yarn.lock

              yarn install --offline
              patchShebangs .

              yarn --offline build
            '';

            installPhase = ''
              mkdir -p $out
              cp -R webui/dist $out
            '';
          };

        packages.default = self'.packages.frontend;
      };
    };
}
