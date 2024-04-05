{
  lib,
  pkgs,
  ...
}: {
  options.homestakeros = with lib; let
    nospace = str: filter (c: c == " ") (stringToCharacters str) == [];
  in {
    localization = {
      hostname = mkOption {
        type = types.strMatching "^$|^[[:alnum:]]([[:alnum:]_-]{0,61}[[:alnum:]])?$";
        default = "homestaker";
        description = "The name of the machine.";
      };
      timezone = mkOption {
        type = types.nullOr (types.addCheck types.str nospace);
        default = null;
        description = "The time zone used when displaying times and dates.";
        example = "America/New_York";
      };
    };

    mounts = mkOption {
      type = types.attrsOf types.attrs;
      default = {};
      description = "Definition of systemd mount units. Click [here](https://www.freedesktop.org/software/systemd/man/systemd.mount.html#Options) for more information.";
      example = {
        my-mount = {
          enable = true;
          description = "A storage device";

          what = "/dev/disk/by-label/my-label";
          where = "/path/to/my/mount";
          options = "noatime";
          type = "btrfs";

          wantedBy = ["multi-user.target"];
        };
      };
    };

    vpn = {
      wireguard = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to enable WireGuard.";
        };
        configFile = mkOption {
          type = types.path;
          default = "/var/mnt/secrets/wg0.conf";
          description = "A file path for the wg-quick configuration.";
        };
      };
    };

    ssh = {
      authorizedKeys = mkOption {
        type = types.listOf types.singleLineStr;
        default = [];
        description = "A list of public SSH keys to be added to the user's authorized keys.";
      };
      privateKeyFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to the Ed25519 SSH host key. If absent, the key will be generated automatically.";
        example = "/var/mnt/secrets/ssh/id_ed25519";
      };
    };

    execution = {
      erigon = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to enable Erigon.";
        };
        endpoint = mkOption {
          type = types.str;
          default = "http://127.0.0.1:8551";
          description = "HTTP-RPC server listening interface of engine API.";
        };
        dataDir = mkOption {
          type = types.path;
          default = "/var/mnt/erigon";
          description = "Data directory for the blockchain.";
        };
        jwtSecretFile = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Path to the token that ensures safe connection between CL and EL.";
          example = "/var/mnt/erigon/jwt.hex";
        };
      };

      geth = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to enable Geth.";
        };
        endpoint = mkOption {
          type = types.str;
          default = "http://127.0.0.1:8551";
          description = "HTTP-RPC server listening interface of engine API.";
        };
        dataDir = mkOption {
          type = types.path;
          default = "/var/mnt/geth";
          description = "Data directory for the blockchain.";
        };
        jwtSecretFile = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Path to the token that ensures safe connection between CL and EL.";
          example = "/var/mnt/geth/jwt.hex";
        };
      };

      nethermind = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to enable Nethermind.";
        };
        endpoint = mkOption {
          type = types.str;
          default = "http://127.0.0.1:8551";
          description = "HTTP-RPC server listening interface of engine API.";
        };
        dataDir = mkOption {
          type = types.path;
          default = "/var/mnt/nethermind";
          description = "Data directory for the blockchain.";
        };
        jwtSecretFile = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Path to the token that ensures safe connection between CL and EL.";
          example = "/var/mnt/nethermind/jwt.hex";
        };
      };

      besu = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to enable Besu.";
        };
        endpoint = mkOption {
          type = types.str;
          default = "http://127.0.0.1:8551";
          description = "HTTP-RPC server listening interface of engine API.";
        };
        dataDir = mkOption {
          type = types.path;
          default = "/var/mnt/besu";
          description = "Data directory for the blockchain.";
        };
        jwtSecretFile = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Path to the token that ensures safe connection between CL and EL.";
          example = "/var/mnt/besu/jwt.hex";
        };
      };
    };

    consensus = {
      lighthouse = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to enable Lighthouse.";
        };
        endpoint = mkOption {
          type = types.str;
          default = "http://127.0.0.1:5052";
          description = "HTTP server listening interface.";
        };
        execEndpoint = mkOption {
          type = types.str;
          default = "http://127.0.0.1:8551";
          description = "Server endpoint for an execution layer JWT-authenticated HTTP JSON-RPC connection.";
        };
        slasher = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "Whether to enable slasher.";
          };
          historyLength = mkOption {
            type = types.int;
            default = 4096;
            description = "Number of epochs to store.";
          };
          maxDatabaseSize = mkOption {
            type = types.int;
            default = 256;
            description = "Maximum size of the slasher database in gigabytes.";
          };
        };
        dataDir = mkOption {
          type = types.path;
          default = "/var/mnt/lighthouse";
          description = "Data directory for the blockchain.";
        };
        jwtSecretFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Path to the token that ensures safe connection between CL and EL.";
          example = "/var/mnt/lighthouse/jwt.hex";
        };
      };

      prysm = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to enable Prysm.";
        };
        endpoint = mkOption {
          type = types.str;
          default = "http://127.0.0.1:3500";
          description = "JSON-HTTP server listening interface.";
        };
        execEndpoint = mkOption {
          type = types.str;
          default = "http://127.0.0.1:8551";
          description = "Server endpoint for an execution layer JWT-authenticated HTTP JSON-RPC connection.";
        };
        slasher = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "Whether to enable historical slasher.";
          };
        };
        dataDir = mkOption {
          type = types.path;
          default = "/var/mnt/prysm";
          description = "Data directory for the blockchain.";
        };
        jwtSecretFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Path to the token that ensures safe connection between CL and EL.";
          example = "/var/mnt/prysm/jwt.hex";
        };
      };

      teku = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to enable Teku.";
        };
        endpoint = mkOption {
          type = types.str;
          default = "http://127.0.0.1:5051";
          description = "JSON-HTTP server listening interface.";
        };
        execEndpoint = mkOption {
          type = types.str;
          default = "http://127.0.0.1:8551";
          description = "Server endpoint for an execution layer JWT-authenticated HTTP JSON-RPC connection.";
        };
        dataDir = mkOption {
          type = types.path;
          default = "/var/mnt/teku";
          description = "Data directory for the blockchain.";
        };
        jwtSecretFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Path to the token that ensures safe connection between CL and EL.";
          example = "/var/mnt/teku/jwt.hex";
        };
      };

      nimbus = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to enable Nimbus.";
        };
        endpoint = mkOption {
          type = types.str;
          default = "http://127.0.0.1:5052";
          description = "JSON-HTTP server listening interface.";
        };
        execEndpoint = mkOption {
          type = types.str;
          default = "http://127.0.0.1:8551";
          description = "Server endpoint for an execution layer JWT-authenticated HTTP JSON-RPC connection.";
        };
        dataDir = mkOption {
          type = types.path;
          default = "/var/mnt/nimbus";
          description = "Data directory for the blockchain.";
        };
        jwtSecretFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Path to the token that ensures safe connection between CL and EL.";
          example = "/var/mnt/nimbus/jwt.hex";
        };
      };
    };

    addons = {
      ssv-node = {
        privateKeyFile = mkOption {
          type = types.nullOr types.path;
          default = "/var/mnt/addons/ssv/ssv_operator_key";
          description = "Path to the private SSV operator key.";
        };
        privateKeyPasswordFile = mkOption {
          type = types.nullOr types.path;
          default = "/var/mnt/addons/ssv/password";
          description = "Path to the password file of SSV operator key";
        };
        dataDir = mkOption {
          type = types.path;
          default = "/var/mnt/addons/ssv";
          description = "Path to a persistent directory to store the node's database.";
        };
      };
      mev-boost = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to enable MEV-Boost.";
        };
        endpoint = mkOption {
          type = types.str;
          default = "http://127.0.0.1:18550";
          description = "Listening interface for the MEV-Boost server.";
        };
      };
    };
  };
}
