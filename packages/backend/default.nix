{ mkYarnPackage
, ...
}:
mkYarnPackage {
  name = "homestakeros-backend";
  src = ./.;
  packageJSON = ./package.json;
  yarnLock = ./yarn.lock;
  yarnNix = ./yarn.nix;
}
