{
  inputs = {
    nixobolus.url = "github:ponkila/nixobolus/juuso/options-extractions";
  };
  outputs =
    { self
    , nixpkgs
    , flake-utils
    , nixobolus
    , ...
    }@inputs:
    let
      inherit (self) outputs;
      forAllSystems = nixpkgs.lib.genAttrs [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

    in
    {

      erigon = inputs.nixobolus.outputs.exports.erigon.options;

      devShells = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in import ./shell.nix { inherit pkgs; }
      );
    };
}
