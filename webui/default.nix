{ buildNpmPackage
, nodejs
, ...
}:
buildNpmPackage {
  name = "HomestakerOS-frontend";
  version = "0.1.0";

  # The packages required by the build process
  buildInputs = [
    nodejs
  ];

  # The code sources for the package
  src = ./.;
  npmDepsHash = "sha256-n2yxxk7ww6gClyHa2tx8FaFwYHPlTT1Hy2Cwsfy/430=";

  npmBuild = "npm run build";

  # How the output of the build phase
  installPhase = ''
    mkdir $out
    cp -r dist/* $out
  '';
}
