_: {
  homestakeros = {
    addons = {
      mev-boost = {
        enable = false;
        endpoint = "http://127.0.0.1:18550";
      };
      ssv-node = {
        dataDir = "/var/mnt/addons/ssv";
        privateKeyFile = "/var/mnt/addons/ssv/ssv_operator_key";
        privateKeyPasswordFile = "/var/mnt/addons/ssv/password";
      };
    };
    consensus = {
      lighthouse = {
        dataDir = "/var/mnt/lighthouse";
        enable = false;
        endpoint = "http://127.0.0.1:5052";
        execEndpoint = "http://127.0.0.1:8551";
        jwtSecretFile = null;
        slasher = {
          enable = false;
          historyLength = 4096;
          maxDatabaseSize = 256;
        };
      };
      nimbus = {
        dataDir = "/var/mnt/nimbus";
        enable = false;
        endpoint = "http://127.0.0.1:5052";
        execEndpoint = "http://127.0.0.1:8551";
        jwtSecretFile = null;
      };
      prysm = {
        dataDir = "/var/mnt/prysm";
        enable = false;
        endpoint = "http://127.0.0.1:3500";
        execEndpoint = "http://127.0.0.1:8551";
        jwtSecretFile = null;
        slasher = { enable = false; };
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
        enable = false;
        endpoint = "http://127.0.0.1:8551";
        jwtSecretFile = null;
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
      hostname = "homestaker";
      timezone = null;
    };
    mounts = { };
    ssh = {
      authorizedKeys = [ ];
      privateKeyFile = null;
    };
    vpn = {
      wireguard = {
        configFile = "/var/mnt/secrets/wg0.conf";
        enable = false;
      };
    };
  };
}
