{ pkgs, lib, ... }:
let
  frontend = pkgs.callPackage ../frontend { };
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
        --replace webui/dist ${frontend}/webui/dist \
        --replace webui/nixosConfigurations ${frontend}/webui/nixosConfigurations
    '';

    meta = with lib; {
      description = "Backend source code for HomestakerOS";
      license = licenses.mit;
    };
  }