{ lib
, ...
}:
{
  options.homestakeros = with lib; {
    localization = {
      hostname = mkOption {
        type = types.str;
        default = "homestaker";
        description = "The name of the machine.";
      };
      timezone = mkOption {
        type = types.str;
        default = "UTC";
        description = "The time zone used when displaying times and dates.";
        example = "America/New_York";
      };
    };

    mounts = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          enable = lib.mkEnableOption "Whether to enable this mount.";
          description = mkOption {
            type = types.str;
            default = "storage device";
            description = ''
              Description of this unit used in systemd messages and progress indicators.
            '';
            example = "ethereum mainnet";
          };
          what = mkOption {
            type = types.str;
            description = ''
              Absolute path of device node, file or other resource. (Mandatory)
            '';
            example = "/dev/sda1";
          };
          where = mkOption {
            type = types.str;
            description = ''
              Absolute path of a directory of the mount point. Will be created if it doesn't exist. (Mandatory)
            '';
            example = "/mnt";
          };
          type = mkOption {
            type = types.str;
            default = "auto";
            description = "File system type.";
            example = "btrfs";
          };
          options = mkOption {
            type = types.str;
            default = "noatime";
            description = ''
              Options used to mount the file system; strings concatenated with ",".
            '';
            example = "noatime";
          };
          wantedBy = mkOption {
            type = types.listOf types.str;
            default = [ "multi-user.target" ];
            description = "Units that want (i.e. depend on) this unit.";
            example = [ "some-system.target" ];
          };
          before = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = ''
              If the specified units are started at the same time as this unit, delay them until this unit has started.
            '';
            example = [ "some-system.service" ];
          };
        };
      });
      default = { };
      description = "A set of systemd mount definitions.";
      example = {
        myMount = {
          enable = true;
          what = "/dev/sda1";
          where = "/mnt";
          type = "btrfs";
          options = [ "noatime" ];
          before = [ "some-other.service" ];
          wantedBy = [ "multi-user.target" ];
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
          default = "/mnt/secrets/wg0.conf";
          description = "A file path for the wg-quick configuration.";
        };
      };
    };

    ssh = {
      authorizedKeys = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "A list of public SSH keys to be added to the user's authorized keys.";
      };
      privateKeyFile = mkOption {
        type = types.path;
        default = "/mnt/secrets/ssh/id_ed25519";
        description = "Path to the Ed25519 SSH host key. If absent, the key will be generated automatically.";
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
          default = "/mnt/erigon";
          description = "Data directory for the blockchain.";
        };
        jwtSecretFile = mkOption {
          type = types.str;
          default = "/mnt/secrets/jwt.hex";
          description = "Path to the token that ensures safe connection between CL and EL.";
        };
        extraOptions = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Additional command-line arguments.";
          example = [ "--some-extra-option=value" ];
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
          default = "/mnt/geth";
          description = "Data directory for the blockchain.";
        };
        jwtSecretFile = mkOption {
          type = types.str;
          default = "/mnt/secrets/jwt.hex";
          description = "Path to the token that ensures safe connection between CL and EL.";
        };
        extraOptions = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Additional command-line arguments.";
          example = [ "--some-extra-option=value" ];
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
          default = "/mnt/nethermind";
          description = "Data directory for the blockchain.";
        };
        jwtSecretFile = mkOption {
          type = types.str;
          default = "/mnt/secrets/jwt.hex";
          description = "Path to the token that ensures safe connection between CL and EL.";
        };
        extraOptions = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Additional command-line arguments.";
          example = [ "--some-extra-option=value" ];
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
          default = "/mnt/besu";
          description = "Data directory for the blockchain.";
        };
        jwtSecretFile = mkOption {
          type = types.str;
          default = "/mnt/secrets/jwt.hex";
          description = "Path to the token that ensures safe connection between CL and EL.";
        };
        extraOptions = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Additional command-line arguments.";
          example = [ "--some-extra-option=value" ];
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
          default = "/mnt/lighthouse";
          description = "Data directory for the blockchain.";
        };
        jwtSecretFile = mkOption {
          type = types.path;
          default = "/mnt/secrets/jwt.hex";
          description = "Path to the token that ensures safe connection between CL and EL.";
        };
        extraOptions = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Additional command-line arguments.";
          example = [ "--some-extra-option=value" ];
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
          default = "/mnt/prysm";
          description = "Data directory for the blockchain.";
        };
        jwtSecretFile = mkOption {
          type = types.path;
          default = "/mnt/secrets/jwt.hex";
          description = "Path to the token that ensures safe connection between CL and EL.";
        };
        extraOptions = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Additional command-line arguments.";
          example = [ "--some-extra-option=value" ];
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
          default = "/mnt/teku";
          description = "Data directory for the blockchain.";
        };
        jwtSecretFile = mkOption {
          type = types.path;
          default = "/mnt/secrets/jwt.hex";
          description = "Path to the token that ensures safe connection between CL and EL.";
        };
        extraOptions = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Additional command-line arguments.";
          example = [ "--some-extra-option=value" ];
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
          default = "/mnt/nimbus";
          description = "Data directory for the blockchain.";
        };
        jwtSecretFile = mkOption {
          type = types.path;
          default = "/mnt/secrets/jwt.hex";
          description = "Path to the token that ensures safe connection between CL and EL.";
        };
        extraOptions = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Additional command-line arguments.";
          example = [ "--some-extra-option=value" ];
        };
      };
    };

    addons = {
      ssv-node = {
        dataDir = mkOption {
          type = types.path;
          default = "/mnt/addons/ssv";
          description = ''
            Path to a persistent directory to store the node's database and keys.
            Expected files: ssv_operator_key, ssv_operator_key.pub, and password.
            Keys will be generated automatically if missing.
          '';
        };
        extraOptions = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Additional command-line arguments.";
          example = [ "--some-extra-option=value" ];
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
        extraOptions = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Additional command-line arguments.";
          example = [ "--some-extra-option=value" ];
        };
      };
    };
  };
}
