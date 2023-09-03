{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-root.url = "github:srid/flake-root";
    mission-control.url = "github:Platonic-Systems/mission-control";
    nixobolus.url = "github:ponkila/nixobolus";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Web UI
    frontend.url = "github:ponkila/HomestakerOS/feat/pkgs-webui?dir=packages/frontend";
    backend.url = "github:ponkila/HomestakerOS/feat/pkgs-webui?dir=packages/backend";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-parts,
    nixobolus,
    backend,
    frontend,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      imports = [
        inputs.flake-root.flakeModule
        inputs.mission-control.flakeModule
      ];

      perSystem = {
        pkgs,
        lib,
        config,
        inputs',
        system,
        ...
      }: let
        # Function to create a basic shell script package
        # https://www.ertt.ca/nix/shell-scripts/#org6f67de6
        mkScriptPackage = {
          name,
          deps,
        }: let
          pkgs = import nixpkgs {inherit system;};
          scriptPath = ./scripts/${name}.sh;
          script = (pkgs.writeScriptBin name (builtins.readFile scriptPath)).overrideAttrs (old: {
            buildCommand = "${old.buildCommand}\n patchShebangs $out";
          });
        in
          pkgs.symlinkJoin {
            inherit name;
            paths = [script] ++ deps;
            buildInputs = [pkgs.makeWrapper];
            postBuild = "wrapProgram $out/bin/${name} --prefix PATH : $out/bin";
          };
      in rec {
        formatter = nixpkgs.legacyPackages.${system}.alejandra;

        mission-control.scripts = {
          schema = {
            description = "Update schema using current version of nixobolus";
            exec = ''
              nix eval --json .#schema | jq > webui/public/schema.json
            '';
            category = "Development Tools";
          };
          server = {
            description = "Initialize and launch the web server";
            exec = ''
              export NIX_CONFIG='warn-dirty = false' \
              && nix eval --json .#schema | jq > packages/frontend/webui/public/schema.json \
              && git add packages/frontend/webui/public/schema.json \
              && nix run .#update-json \
              && nix run .#backend 
            '';
            category = "Essentials";
          };
        };

        devShells = {
          default = pkgs.mkShell {
            nativeBuildInputs = with pkgs; [
              nodejs
              jq
              yarn
              yarn2nix
            ];
            inputsFrom = [
              config.flake-root.devShell
              config.mission-control.devShell
            ];
          };
        };

        apps = {
          json2nix = {
            type = "app";
            program = "${self.packages.${system}.json2nix}/bin/json2nix";
          };
          buidl = {
            type = "app";
            program = "${self.packages.${system}.buidl}/bin/buidl";
          };
          init-ssv = {
            type = "app";
            program = "${self.packages.${system}.init-ssv}/bin/init-ssv";
          };
          update-json = {
            type = "app";
            program = "${self.packages.${system}.update-json}/bin/update-json";
          };
        };

        packages = {
          "json2nix" = mkScriptPackage {
            name = "json2nix";
            deps = [pkgs.nix];
          };
          "buidl" = mkScriptPackage {
            name = "buidl";
            deps = [
              pkgs.nix
              pkgs.jq
              pkgs.git
              self.packages.${system}.json2nix
              self.packages.${system}.update-json
            ];
          };
          "init-ssv" = mkScriptPackage {
            name = "init-ssv";
            deps = [nixobolus.inputs.ethereum-nix.packages."x86_64-linux".ssvnode];
          };
          "update-json" = mkScriptPackage {
            name = "update-json";
            deps = [
              pkgs.nix
              pkgs.jq
            ];
          };

          frontend = inputs'.frontend.packages.default;
          backend = inputs'.backend.packages.default;
          default = packages.backend;
        };
      };

      flake = let
        inherit (self) outputs;
        system = "x86_64-linux";
      in {
        nixosConfigurations = let
          configDir = "${self}/packages/frontend/nixosConfigurations";
          ls = builtins.readDir configDir;
          hostnames =
            builtins.filter
            (name: builtins.hasAttr name ls && (ls.${name} == "directory"))
            (builtins.attrNames ls);
        in
          nixpkgs.lib.mkIf (
            builtins.pathExists configDir
          ) (
            builtins.listToAttrs (map (hostname: {
                name = hostname;
                value = nixpkgs.lib.nixosSystem {
                  inherit system;
                  specialArgs = {inherit inputs outputs;};
                  modules =
                    [
                      nixobolus.nixosModules.kexecTree
                      nixobolus.nixosModules.homestakeros
                      configDir/${hostname}
                      {
                        system.stateVersion = "23.05";
                        # Bootloader for x86_64-linux / aarch64-linux
                        boot.loader.systemd-boot.enable = true;
                        boot.loader.efi.canTouchEfiVariables = true;
                      }
                    ];
                };
              })
              hostnames)
          );

        schema = nixobolus.outputs.exports.homestakeros;
      };
    };
}
