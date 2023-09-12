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
        dataDir = "/var/mnt/erigon";
        enable = true;
        endpoint = "http://192.168.100.10:8551";
        jwtSecretFile = "/var/mnt/erigon/jwt.hex";
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
      authorizedKeys = ["ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBNMKgTTpGSvPG4p8pRUWg1kqnP9zPKybTHQ0+Q/noY5+M6uOxkLy7FqUIEFUT9ZS/fflLlC/AlJsFBU212UzobA= ssh@secretive.sandbox.local" "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKEdpdbTOz0h9tVvkn13k1e8X7MnctH3zHRFmYWTbz9T kari@torque" "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAID5aw7sqJrXdKdNVu9IAyCCw1OYHXFQmFu/s/K+GAmGfAAAABHNzaDo= da@pusu" "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAINwWpZR5WuzyJlr7jYoe0mAYp+MJ12doozfqGz9/8NP/AAAABHNzaDo= da@pusu" "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCkfHIgiK8S5awFn+oOdduS2mp5UGT4ki/ndoMArBol1dvRSKAdHS4okCX/umiy4BqAsDFkpYWuwe897NdOosba0iVyrFsYRou9FrOnQIMRIgtAvaOXeo2U4432glzH4WsMD+D+F4wHZ7walsrkaIPihpoHtWp8DkTPcFm1D8GP1o5TNpTjSFSuPFSzC2nburVcyfxZJluh/hxnxtYLNrmwOOHLhXcTmy5rQQ5u2HI5y64tS6fnKxxozA2gPaVro5+W5e3WtpSDGdd2NkPDzrMMmwYFEv4Tw9ooUfaJhXhq7AJakK/nTfpLquL9XSia8af+aOzx/p1v25f56dESlhNzcSlREP52hTA9T3foCA2IBkDitBeeGhUeeerQdczoRFxxSjoI244bPwAZ+tKIwO0XFaxLyd3jjzlya0F9w1N7wN0ZO4hY1NVv7oaYTUcU7TnvqGEMGLZpQBnIn7DCrUjKeW4AIUGvxcCP+F16lqFkuLSCgOAHM59NECVwBAOPGDk="];
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