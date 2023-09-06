{
  pkgs,
  lib,
  ...
}: let
  src = ./.;
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
      fixup_yarn_lock yarn.lock

      yarn install --offline
      patchShebangs .

      yarn --offline build
    '';

    installPhase = ''
      mkdir -p $out
      cp -R . $out
    '';

    meta = with lib; {
      description = "Frontend source code for HomestakerOS";
      license = licenses.mit;
    };
  }
