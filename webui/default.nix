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
  npmDepsHash = "sha256-jFIlfKrIGJolkjmYoleQ1nbmOgG246uMjbehAsZUf+c=";

  npmBuild = "npm run build";

  # How the output of the build phase
  installPhase = ''
    mkdir $out
    cp -r dist/* $out
  '';

  makeCacheWritable = true;
}
