{
  pkgs,
  config,
  inputs,
  lib,
  ...
}: {
  homestakeros = {
    addons = {
      mev-boost = {
        enable = true;
        endpoint = "http://192.168.100.31:18550";
      };
    };
    consensus = {
      lighthouse = {
        dataDir = "/mnt/eth/lighthouse";
        enable = true;
        endpoint = "http://192.168.100.31:5052";
        execEndpoint = "http://192.168.100.31:8551";
        jwtSecretFile = "/mnt/eth/lighthouse/jwt.hex";
        slasher = {
          enable = false;
          historyLength = 256;
          maxDatabaseSize = 16;
        };
      };
      prysm = {
        dataDir = "/var/mnt/prysm";
        enable = false;
        endpoint = "http://127.0.0.1:3500";
        execEndpoint = "http://127.0.0.1:8551";
        jwtSecretFile = null;
        slasher = {enable = false;};
      };
      teku = {
        dataDir = "/var/mnt/teku";
        enable = false;
        endpoint = "http://127.0.0.1:5051";
        execEndpoint = "http://127.0.0.1:8551";
        jwtSecretFile = null;
      };
    };
    execution = {
      besu = {
        dataDir = "/var/mnt/besu";
        enable = false;
        endpoint = "http://127.0.0.1:8551";
        jwtSecretFile = null;
      };
      erigon = {
        dataDir = "/mnt/eth/erigon";
        enable = true;
        endpoint = "http://192.168.100.31:8551";
        jwtSecretFile = "/mnt/eth/erigon/jwt.hex";
      };
      geth = {
        dataDir = "/var/mnt/geth";
        enable = false;
        endpoint = "http://127.0.0.1:8551";
        jwtSecretFile = null;
      };
      nethermind = {
        dataDir = "/var/mnt/nethermind";
        enable = false;
        endpoint = "http://127.0.0.1:8551";
        jwtSecretFile = null;
      };
    };
    localization = {
      hostname = "dinar-ephemeral-alpha";
      timezone = "Europe/Helsinki";
    };
    mounts = {
      eth = {
        before = ["sops-nix.service" "sshd.service"];
        description = "storage";
        enable = true;
        type = "ext4";
        wantedBy = ["multi-user.target"];
        what = "/dev/sda1";
        where = "/mnt/eth";
      };
    };
    ssh = {
      authorizedKeys = ["ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBNMKgTTpGSvPG4p8pRUWg1kqnP9zPKybTHQ0+Q/noY5+M6uOxkLy7FqUIEFUT9ZS/fflLlC/AlJsFBU212UzobA= ssh@secretive.sandbox.local" "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKEdpdbTOz0h9tVvkn13k1e8X7MnctH3zHRFmYWTbz9T kari@torque" "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAID5aw7sqJrXdKdNVu9IAyCCw1OYHXFQmFu/s/K+GAmGfAAAABHNzaDo= da@pusu" "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAINwWpZR5WuzyJlr7jYoe0mAYp+MJ12doozfqGz9/8NP/AAAABHNzaDo= da@pusu"];
      privateKeyFile = "/mnt/eth/secrets/ssh/id_ed25519";
    };
    vpn = {
      wireguard = {
        configFile = "/run/secrets/wireguard/wg0";
        enable = true;
        interfaceName = "wg0";
      };
    };
  };
}
