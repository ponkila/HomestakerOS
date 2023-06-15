{
  inputs = {
    nixobolus.url = "github:ponkila/nixobolus";
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

      erigon = inputs.nixobolus.outputs.exports.erigon;

      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {

          default = pkgs.mkShell {
            # Enable experimental features without having to specify the argument
            NIX_CONFIG = "experimental-features = nix-command flakes";
            nativeBuildInputs = with pkgs; [
              nodejs
              just
            ];
          };

        }
      );
    };
}
