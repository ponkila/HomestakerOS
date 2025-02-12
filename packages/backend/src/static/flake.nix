{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    homestakeros.url = "github:ponkila/HomestakerOS";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    ponkila.url = "github:ponkila/HomestakerOS?dir=nixosModules/base";
  };

  outputs = { ... }@inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = inputs.nixpkgs.lib.systems.flakeExposed;
      flake = {
        nixosConfigurations =
          let
            ls = builtins.readDir ./nixosConfigurations;
            hostnames =
              builtins.filter
                (name: builtins.hasAttr name ls && (ls.${name} == "directory"))
                (builtins.attrNames ls);
          in
          inputs.nixpkgs.lib.mkIf
            (
              builtins.pathExists ./nixosConfigurations
            )
            (
              builtins.listToAttrs (map
                (hostname: {
                  name = hostname;
                  value = inputs.nixpkgs.lib.nixosSystem {
                    system = "x86_64-linux";
                    specialArgs = { inherit inputs; };
                    modules = [
                      inputs.ponkila.nixosModules.base
                      inputs.ponkila.nixosModules.kexecTree
                      inputs.homestakeros.nixosModules.homestakeros
                      ./nixosConfigurations/${hostname}
                      {
                        system.stateVersion = "24.11";
                      }
                    ];
                  };
                })
                hostnames)
            );
      };
    };
}
