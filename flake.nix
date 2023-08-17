{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-root.url = "github:srid/flake-root";
    mission-control.url = "github:Platonic-Systems/mission-control";
    nixobolus.url = "github:ponkila/nixobolus";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-parts,
    nixobolus,
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
        system,
        ...
      }: rec {
        formatter = nixpkgs.legacyPackages.${system}.alejandra;

        mission-control.scripts = {
          schema = {
            description = "Update schema using current version of nixobolus";
            exec = ''
              nix eval --json .#schema | jq > webui/schema.json
            '';
            category = "Development Tools";
          };
          server = {
            description = "Initialize and launch the web server";
            exec = ''
              nix eval --json .#schema | jq > webui/schema.json \
              && if [ ! -p "webui/pipe" ]; then mkfifo webui/pipe; fi \
              && nix run .#
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
        };

        # https://www.ertt.ca/nix/shell-scripts/#org6f67de6
        packages = {
          "json2nix" = let
            pkgs = import nixpkgs {inherit system;};
            name = "json2nix";
            json2nix-script = (pkgs.writeScriptBin name (builtins.readFile ./scripts/json2nix.sh)).overrideAttrs (old: {
              buildCommand = "${old.buildCommand}\n patchShebangs $out";
            });
          in
            pkgs.symlinkJoin {
              inherit name;
              paths = [json2nix-script];
              buildInputs = with pkgs; [nix makeWrapper];
              postBuild = "wrapProgram $out/bin/${name} --prefix PATH : $out/bin";
            };
          "buidl" = let
            pkgs = import nixpkgs {inherit system;};
            name = "buidl";
            my-buildInputs = with pkgs; [ nix jq ] ++ [self.packages.${system}.json2nix];
            buidl-script = (pkgs.writeScriptBin name (builtins.readFile ./scripts/buidl.sh)).overrideAttrs (old: {
              buildCommand = "${old.buildCommand}\n patchShebangs $out";
            });
          in
            pkgs.symlinkJoin {
              inherit name;
              paths = [buidl-script] ++ my-buildInputs;
              buildInputs = [ pkgs.makeWrapper ];
              postBuild = "wrapProgram $out/bin/${name} --prefix PATH : $out/bin";
            };
        };

        packages.homestakeros = pkgs.mkYarnPackage {
          pname = "homestakeros";
          version = "0.0.1";

          src = ./.;
          packageJSON = ./package.json;
          yarnLock = ./yarn.lock;
          yarnNix = ./yarn.nix;
        };

        packages.default = packages.homestakeros;
      };

      flake = let
        inherit (self) outputs;
        system = "x86_64-linux";
      in {
        nixosConfigurations = let
          ls = builtins.readDir ./nixosConfigurations;
          hostnames =
            builtins.filter
            (name: builtins.hasAttr name ls && (ls.${name} == "directory"))
            (builtins.attrNames ls);
        in
          builtins.listToAttrs (map (hostname: {
              name = hostname;
              value = nixpkgs.lib.nixosSystem {
                inherit system;
            specialArgs = {inherit inputs outputs;};
            modules = [
              nixobolus.nixosModules.kexecTree
              nixobolus.nixosModules.homestakeros
                  ./nixosConfigurations/${hostname}
              {
                system.stateVersion = "23.05";
                # Bootloader for x86_64-linux / aarch64-linux
                boot.loader.systemd-boot.enable = true;
                boot.loader.efi.canTouchEfiVariables = true;
              }
            ];
          };
            })
            hostnames);

        schema = nixobolus.outputs.exports.homestakeros;
      };
    };
}
