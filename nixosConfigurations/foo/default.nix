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
        endpoint = "http://192.168.100.10:18550";
      };
    };
    consensus = {
      lighthouse = {
        dataDir = "/var/mnt/lighthouse";
        enable = true;
        endpoint = "http://192.168.100.10:5052";
        execEndpoint = "http://192.168.100.10:8551";
        jwtSecretFile = "/var/mnt/lighthouse/jwt.hex";
        slasher = {
          enable = false;
          historyLength = 256;
          maxDatabaseSize = 16;
        };
      };
    };
    execution = {
      erigon = {
        dataDir = "/var/mnt/erigon";
        enable = true;
        endpoint = "http://192.168.100.10:8551";
        jwtSecretFile = "/var/mnt/erigon/jwt.hex";
      };
    };
    localization = {
      hostname = "ponkila-ephemeral-beta";
      timezone = "Europe/Helsinki";
    };
    mounts = {
      erigon = {
        description = "erigon storage";
        enable = true;
        options = "noatime";
        type = "btrfs";
        wantedBy = ["multi-user.target"];
        what = "/dev/disk/by-label/erigon";
        where = "/var/mnt/erigon";
      };
      lighthouse = {
        description = "lighthouse storage";
        enable = true;
        options = "noatime";
        type = "btrfs";
        wantedBy = ["multi-user.target"];
        what = "/dev/disk/by-label/lighthouse";
        where = "/var/mnt/lighthouse";
      };
    };
    ssh = {
      authorizedKeys = ["ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBNMKgTTpGSvPG4p8pRUWg1kqnP9zPKybTHQ0+Q/noY5+M6uOxkLy7FqUIEFUT9ZS/fflLlC/AlJsFBU212UzobA= ssh@secretive.sandbox.local" "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKEdpdbTOz0h9tVvkn13k1e8X7MnctH3zHRFmYWTbz9T kari@torque" "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAID5aw7sqJrXdKdNVu9IAyCCw1OYHXFQmFu/s/K+GAmGfAAAABHNzaDo= da@pusu" "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAINwWpZR5WuzyJlr7jYoe0mAYp+MJ12doozfqGz9/8NP/AAAABHNzaDo= da@pusu"];
      privateKeyFile = "/var/mnt/secrets/ssh/id_ed25519";
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
