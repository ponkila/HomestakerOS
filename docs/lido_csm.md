
# Lido CSM

_Running Lido CSM using NixOS using publicly accessible configurations_

## Introduction

At Ponkila we have been running Ethereum staking service using NixOS.
NixOS enables the creation of a complete operating system for homestaking.
As the landscape of staking services develop, NixOS provides agility and dependability for maintaining an up-to-date system.
Compared to Docker, NixOS allows modeling of multiple computers to work in a cluster, by enabling networking to also be programmed.

NixOS machines are defined using a language called Nix, which can be considered a form of programmable JSON.
It is possible to compile the Nix files to produce a disk image of a Linux system.
The Linux system is composed of a kernel and an initial ramdisk, which can be booted in various ways, including but not limited to PXE, rEFInd, and kexec.
Kexec in particular is a useful format, as it makes possible to produce a bash script that can be run on some existing Linux computer.
Double-clicking the kexec file or running it via command line "jumps" the Linux distribution into the new system seamlessly, where the operating system is now held in RAM.

## Lido CSM

Ponkila was chosen to the testnet of Lido CSM using SSV as the DVT.
For this case, we created a new node in our [homestaking-infra](https://github.com/ponkila/homestaking-infra) repository that houses all our node configurations in a public manner.
In specific, the PR [kaakkuri-ephemeral-alpha: init](https://github.com/ponkila/homestaking-infra/pull/88) includes the complete diffset that added two testnet nodes into our infrastructure, while also bootstrapping mesh network using Wireguard, and started using agenix-rekey as a secrets _generator_.

Bootstrapping the node required us to also make a few upstream commits to the community maintained repository for Ethereum, called [ethereum.nix](https://github.com/nix-community/ethereum.nix).
We initiated a few PRs to get all the software bundled:
- https://github.com/nix-community/ethereum.nix/pull/542
- https://github.com/nix-community/ethereum.nix/pull/547

The first PR packages ssv-dkg, whereas the second one includes changes required to run the new v2 version of ssvnode.
In particular, the second PR found [a seemingly an upstream issue in ssvnode](https://github.com/ssvlabs/ssv/issues/1765), which assumes OpenSSL to be installed in the system.
NixOS often finds these kinds of issues, since it is much more isolated distribution compared to alternatives.

Next, we go over the whole composition of our new node.

To start off, we bootstrap the node:

```nix
  homestakeros = {
    # Localization options
    localization = {
      hostname = "kaakkuri-ephemeral-alpha";
      timezone = "Europe/Helsinki";
    };

    # SSH options
    ssh = {
      authorizedKeys = [
        "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBNMKgTTpGSvPG4p8pRUWg1kqnP9zPKybTHQ0+Q/noY5+M6uOxkLy7FqUIEFUT9ZS/fflLlC/AlJsFBU212UzobA= ssh@secretive.sandbox.local"
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAID5aw7sqJrXdKdNVu9IAyCCw1OYHXFQmFu/s/K+GAmGfAAAABHNzaDo= da@pusu"
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAINwWpZR5WuzyJlr7jYoe0mAYp+MJ12doozfqGz9/8NP/AAAABHNzaDo= da@pusu"
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCkfHIgiK8S5awFn+oOdduS2mp5UGT4ki/ndoMArBol1dvRSKAdHS4okCX/umiy4BqAsDFkpYWuwe897NdOosba0iVyrFsYRou9FrOnQIMRIgtAvaOXeo2U4432glzH4WsMD+D+F4wHZ7walsrkaIPihpoHtWp8DkTPcFm1D8GP1o5TNpTjSFSuPFSzC2nburVcyfxZJluh/hxnxtYLNrmwOOHLhXcTmy5rQQ5u2HI5y64tS6fnKxxozA2gPaVro5+W5e3WtpSDGdd2NkPDzrMMmwYFEv4Tw9ooUfaJhXhq7AJakK/nTfpLquL9XSia8af+aOzx/p1v25f56dESlhNzcSlREP52hTA9T3foCA2IBkDitBeeGhUeeerQdczoRFxxSjoI244bPwAZ+tKIwO0XFaxLyd3jjzlya0F9w1N7wN0ZO4hY1NVv7oaYTUcU7TnvqGEMGLZpQBnIn7DCrUjKeW4AIUGvxcCP+F16lqFkuLSCgOAHM59NECVwBAOPGDk="
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJdbU8l66hVUAqk900GmEme5uhWcs05JMUQv2eD0j7MI juuso@starlabs"
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOdsfK46X5IhxxEy81am6A8YnHo2rcF2qZ75cHOKG7ToAAAACHNzaDprYXJp ssh:kari"
      ];
    };

  };
```

This bootstraps the node with some authorized ssh keys, sets the hostname, and the timezone of the node.

We then attach a filesystem to be mounted when the node starts:

```nix
  boot.initrd.availableKernelModules = [ "xfs" ];
  fileSystems."/var/mnt/ssd" = lib.mkImageMediaOverride {
    fsType = "xfs";
    device = "/dev/mapper/samsung-ssd";
    neededForBoot = true;
  };
```

This loads the support of `xfs` filesystem into the operating system, while mounting the LVM logical volume called `samsung-ssd` into `/var/mnt/ssd`.

We then created a `secrets` folder in the directory, where we placed persisten ssh keys and a wireguard configuration:

```nix
let
  sshKeysPath = "/var/mnt/ssd/secrets/ssh/id_ed25519";
in
{
  boot.initrd.availableKernelModules = [ "xfs" ];
  fileSystems."/var/mnt/ssd" = lib.mkImageMediaOverride {
    fsType = "xfs";
    device = "/dev/mapper/samsung-ssd";
    neededForBoot = true;
  };

  homestakeros = {
    # Localization options
    localization = {
      hostname = "kaakkuri-ephemeral-alpha";
      timezone = "Europe/Helsinki";
    };

    # SSH options
    ssh = {
      authorizedKeys = [
        "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBNMKgTTpGSvPG4p8pRUWg1kqnP9zPKybTHQ0+Q/noY5+M6uOxkLy7FqUIEFUT9ZS/fflLlC/AlJsFBU212UzobA= ssh@secretive.sandbox.local"
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAID5aw7sqJrXdKdNVu9IAyCCw1OYHXFQmFu/s/K+GAmGfAAAABHNzaDo= da@pusu"
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAINwWpZR5WuzyJlr7jYoe0mAYp+MJ12doozfqGz9/8NP/AAAABHNzaDo= da@pusu"
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCkfHIgiK8S5awFn+oOdduS2mp5UGT4ki/ndoMArBol1dvRSKAdHS4okCX/umiy4BqAsDFkpYWuwe897NdOosba0iVyrFsYRou9FrOnQIMRIgtAvaOXeo2U4432glzH4WsMD+D+F4wHZ7walsrkaIPihpoHtWp8DkTPcFm1D8GP1o5TNpTjSFSuPFSzC2nburVcyfxZJluh/hxnxtYLNrmwOOHLhXcTmy5rQQ5u2HI5y64tS6fnKxxozA2gPaVro5+W5e3WtpSDGdd2NkPDzrMMmwYFEv4Tw9ooUfaJhXhq7AJakK/nTfpLquL9XSia8af+aOzx/p1v25f56dESlhNzcSlREP52hTA9T3foCA2IBkDitBeeGhUeeerQdczoRFxxSjoI244bPwAZ+tKIwO0XFaxLyd3jjzlya0F9w1N7wN0ZO4hY1NVv7oaYTUcU7TnvqGEMGLZpQBnIn7DCrUjKeW4AIUGvxcCP+F16lqFkuLSCgOAHM59NECVwBAOPGDk="
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJdbU8l66hVUAqk900GmEme5uhWcs05JMUQv2eD0j7MI juuso@starlabs"
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOdsfK46X5IhxxEy81am6A8YnHo2rcF2qZ75cHOKG7ToAAAACHNzaDprYXJp ssh:kari"
      ];
      privateKeyFile = sshKeysPath;
    };

    # Wireguard options
    vpn.wireguard = {
      enable = true;
      configFile = "/var/mnt/ssd/secrets/wg0.conf";
    };

  };
```

Now, the system has Wireguard set up as a VPN, and it loads the ssh keys stored in the persistent volume to be used by OpenSSH.

To use NixOS for Lido CSM, we can start by defining the execution layer (EL) client.
Suppose we start with `geth`:

```nix
  systemd.services.geth = {
    enable = true;

    description = "holesky el";
    requires = [ "wg-quick-wg0.service" ];
    after = [ "wg-quick-wg0.service" ];

    script = ''${pkgs.geth}/bin/geth \
      --datadir /var/mnt/ssd/ethereum/holesky/geth \
      --http --http.addr 192.168.100.50 --http.api="engine,eth,web3,net,debug" --http.port 8545 \
      --ws --ws.api="engine,eth,web3,net,debug" \
      --http.corsdomain "*" \
      --http.vhosts "*" \
      --holesky \
      --authrpc.jwtsecret=${config.age.secrets."holesky-jwt".path} \
      --metrics \
      --metrics.addr 127.0.0.1 \
      --maxpeers 100
    '';

    wantedBy = [ "multi-user.target" ];
  };
```

We use systemd to manage the services.
This allows us to orchestrate geth to start after we have acquired connection on the Wireguard interface, by using the `requires` and `after` fields.
The geth package is pulled from ethereum.nix and uses quite standard options to run the node.
The JWT token is generated on each node upgrade, which we cover in a later section.

Next, we need a consensus layer (CL) client:

```nix
  systemd.services.lighthouse = {
    enable = true;

    description = "holesky cl";
    requires = [ "wg-quick-wg0.service" ];
    after = [ "wg-quick-wg0.service" ];

    script = ''${pkgs.lighthouse}/bin/lighthouse bn \
      --network holesky \
      --execution-endpoint http://localhost:8551 \
      --execution-jwt ${config.age.secrets."holesky-jwt".path} \
      --checkpoint-sync-url https://holesky.beaconstate.ethstaker.cc/ \
      --http \
      --datadir /var/mnt/ssd/ethereum/holesky/lighthouse \
      --builder http://127.0.0.1:18550 \
      --metrics
    '';

    wantedBy = [ "multi-user.target" ];
  };
```

Then, we need MEV-boost:

```nix
  systemd.services.mev-boost = {
    enable = true;

    description = "holesky mev";
    requires = [ "wg-quick-wg0.service" ];
    after = [ "wg-quick-wg0.service" ];

    script = ''${pkgs.mev-boost}/bin/mev-boost \
      -holesky \
      -addr 127.0.0.1:18550 \
      -relay-check \
      -relays "https://0x821f2a65afb70e7f2e820a925a9b4c80a159620582c1766b1b09729fec178b11ea22abb3a51f07b288be815a1a2ff516@bloxroute.holesky.blxrbdn.com,https://0xaa58208899c6105603b74396734a6263cc7d947f444f396a90f7b7d3e65d102aec7e5e5291b27e08d02c50a050825c2f@holesky.titanrelay.xyz,https://0xab78bf8c781c58078c3beb5710c57940874dd96aef2835e7742c866b4c7c0406754376c2c8285a36c630346aa5c5f833@holesky.aestus.live,https://0xafa4c6985aa049fb79dd37010438cfebeb0f2bd42b115b89dd678dab0670c1de38da0c4e9138c9290a398ecd9a0b3110@boost-relay-holesky.flashbots.net,https://0xb1559beef7b5ba3127485bbbb090362d9f497ba64e177ee2c8e7db74746306efad687f2cf8574e38d70067d40ef136dc@relay-stag.ultrasound.money"
    '';

    wantedBy = [ "multi-user.target" ];
  };
```

Then, we need SSV node:

```nix
  systemd.services.ssvnode =
    let
      c = pkgs.writeText "config.yaml" ''
        global:
          LogFileBackups: 28
          LogFilePath: /var/mnt/ssd/ethereum/holesky/ssvnode/debug.log
          LogLevel: info

        db:
          Path: /var/mnt/ssd/ethereum/holesky/ssvnode/db

        ssv:
          Network: holesky
          ValidatorOptions:
            BuilderProposals: true

        eth2:
          BeaconNodeAddr: http://localhost:5052

        eth1:
          ETH1Addr: ws://localhost:8546

        p2p:
          # Optionally provide the external IP address of the node, if it cannot be automatically determined.
          # HostAddress: 192.168.1.1

          # Optionally override the default TCP & UDP ports of the node.
          # TcpPort: 13001
          # UdpPort: 12001

        KeyStore:
          PrivateKeyFile: ${config.sops.secrets."holesky/ssvnode/privateKey".path}
          PasswordFile: ${config.sops.secrets."holesky/ssvnode/password".path}

        MetricsAPIPort: 15000
      '';
    in
    {
      enable = true;

      description = "holesky ssvnode";

      serviceConfig = {
        Restart = "on-failure";
        RestartSec = 5;
      };

      script = ''${pkgs.ssvnode}/bin/ssvnode start-node -c ${c}'';

      wantedBy = [ "multi-user.target" ];
    };
```

To open ports, we can do:

```nix
  networking = {
    firewall = {
      allowedTCPPorts = [
        # NAT routes
        13001 # SSV
        30303 # geth discovery
        9001 # lighthouse discovery

        # Internal
        8545 # holesky RPC
      ];
      allowedUDPPorts = [
        12001 # SSV
        30303
        9001
      ];
    };
  };
```

This would now have everything needed to run the CSM.

## Managing secrets

NixOS comes with various ways to manage secrets and do automatic provisioning.
At Ponkila, we use `age` and `sops` to manage secrets using Yubikeys and PGP devices like Trezors.

For example, it is possible to generate the JWT tokens as follows:

```nix
  age = {
    generators.jwt = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 32";
    rekey = {
      agePlugins = [ pkgs.age-plugin-fido2-hmac ];
      hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF2U2OFXrH4ZT3gSYrTK6ZNkXTfGZQ5BhLh4cBelzzMF";
    };
    secrets = {
      holesky-jwt = {
        rekeyFile = ./secrets/agenix/holesky-jwt.age;
        generator.script = "jwt";
      };
    };
  };
```

This age module creates a JWT generator for us, which we then reference in our configurations using `${config.age.secrets."holesky-jwt".path}`.
This way, the JWT token does not have to be manually created.

For secrets that should not be regenerated, we can use `sops`:

```nix
  sops = {
    defaultSopsFile = ./secrets/default.yaml;
    secrets."holesky/ssvnode/password" = { };
    secrets."holesky/ssvnode/privateKey" = { };
    secrets."holesky/ssvnode/publicKey" = { };
    age.sshKeyPaths = [ sshKeysPath ];
  };
```

This allows the developer machine to first create the required files for ssvnode, which we then refer in our configurations as such:

```nix
          PrivateKeyFile: ${config.sops.secrets."holesky/ssvnode/privateKey".path}
          PasswordFile: ${config.sops.secrets."holesky/ssvnode/password".path}
```

## Monitoring

For monitoring we use netdata.
We have alerts that ping us on our Matrix server.
We also enable smartd to monitor the health of our SSDs:

```nix
  services.netdata = {
    enable = true;
    configDir = {
      "health_alarm_notify.conf" = config.sops.secrets."netdata/health_alarm_notify.conf".path;
      "go.d/prometheus.conf" = pkgs.writeText "go.d/prometheus.conf" ''
        jobs:
          - name: ssv
            url: http://127.0.0.1:15000/metrics
          - name: ssv_health
            url: http://127.0.0.1:15000/health
          - name: geth
            url: http://127.0.0.1:6060/debug/metrics/prometheus
          - name: lighthouse
            url: http://127.0.0.1:5054/metrics
          - name: electrs
            url: http://127.0.0.1:4224/metrics
      '';
      "health.d/ssv_node_status" = pkgs.writeText "health.d/ssv_node_status.conf" ''
        alarm: jesse, juuso: ssv_node_status
        lookup: min -10s
        on: prometheus_ssv.ssv_node_status
        every: 10s
        warn: $this == 0
      '';
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/log/smartd 0755 netdata netdata -"
  ];
  services.smartd = {
    enable = true;
    extraOptions = [
      "-A /var/log/smartd/"
      "--interval=600"
    ];
  };
```

Here, we add the Prometheus endpoints of the client software to be collected by netdata.
This allows us to create health alerts which pings us when the SSV node status goes to 0 (means connection failure).

## Mesh networking

Something we started experimenting with is Wireguard mesh networks.
This allows the nodes to be connected in P2P manner to each other, using optimized network routes to connect to other nodes.
This is a way to create load balancing into our endpoints while avoiding single point of failure that would be a Wireguard server running somewhere:

```nix
  wirenix = {
    enable = true;
    peerName = "kaakkuri"; # defaults to hostname otherwise
    configurer = "networkd"; # defaults to "static", could also be "networkd"
    keyProviders = [ "agenix-rekey" ]; # could also be ["agenix-rekey"] or ["acl" "agenix-rekey"]
    secretsDir = ../../nixosModules/wirenix/agenix; # only if you're using agenix-rekey
    aclConfig = import ../../nixosModules/wirenix/acl.nix;
  };
```

With agenix-rekey, this system automatically creates the Wireguard servers on each node that acts as a mesh network.

One thing that it allows us to do is creation of etcd cluster:

```nix
  services.etcd =
    let
      inherit (inputs.clib.lib.network.ipv6) fromString;
      self = map (x: x.address) (map fromString config.systemd.network.networks."50-simple".address);
      clusterAddr = map (node: "${node.wirenix.peerName}=${toString (map (wg: "http://[${wg.address}]") (map fromString node.systemd.network.networks."50-simple".address))}:2380");
      kaakkuri = clusterAddr [ outputs.nixosConfigurations."kaakkuri-ephemeral-alpha".config ];
      node1 = clusterAddr [ outputs.nixosConfigurations."hetzner-ephemeral-alpha".config ];
      node2 = clusterAddr [ outputs.nixosConfigurations."ponkila-ephemeral-beta".config ];
    in
    {
      enable = true;
      name = config.wirenix.peerName;
      listenPeerUrls = map (x: "http://[${x}]:2380") self;
      listenClientUrls = map (x: "http://[${x}]:2379") self;
      initialClusterToken = "etcd-cluster-1";
      initialClusterState = "new";
      initialCluster = kaakkuri ++ node1 ++ node2;
      dataDir = "/var/mnt/ssd/etcd";
      openFirewall = true;
    };
```

This allows information to be shared as a kv-storage system across the nodes.
This is useful in future work, in which we plan to run the node software as systemd-nspawn containers.
Using etcd with software abstraction like flannel will allow service discovery to happen between nodes: we can then address nodes by software endpoints via DNS, and not via an IP address.
For example, spawning a geth client could bind into DNS endpoint such as `geth.kaakkuri.ponkila.intra`.

## Wrapping up

The complete system definition now looks like this:

```nix
{ lib
, config
, pkgs
, inputs
, outputs
, ...
}:
let
  sshKeysPath = "/var/mnt/ssd/secrets/ssh/id_ed25519";
in
{
  boot.initrd.availableKernelModules = [ "xfs" ];
  fileSystems."/var/mnt/ssd" = lib.mkImageMediaOverride {
    fsType = "xfs";
    device = "/dev/mapper/samsung-ssd";
    neededForBoot = true;
  };

  homestakeros = {
    # Localization options
    localization = {
      hostname = "kaakkuri-ephemeral-alpha";
      timezone = "Europe/Helsinki";
    };

    # SSH options
    ssh = {
      authorizedKeys = [
        "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBNMKgTTpGSvPG4p8pRUWg1kqnP9zPKybTHQ0+Q/noY5+M6uOxkLy7FqUIEFUT9ZS/fflLlC/AlJsFBU212UzobA= ssh@secretive.sandbox.local"
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAID5aw7sqJrXdKdNVu9IAyCCw1OYHXFQmFu/s/K+GAmGfAAAABHNzaDo= da@pusu"
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAINwWpZR5WuzyJlr7jYoe0mAYp+MJ12doozfqGz9/8NP/AAAABHNzaDo= da@pusu"
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCkfHIgiK8S5awFn+oOdduS2mp5UGT4ki/ndoMArBol1dvRSKAdHS4okCX/umiy4BqAsDFkpYWuwe897NdOosba0iVyrFsYRou9FrOnQIMRIgtAvaOXeo2U4432glzH4WsMD+D+F4wHZ7walsrkaIPihpoHtWp8DkTPcFm1D8GP1o5TNpTjSFSuPFSzC2nburVcyfxZJluh/hxnxtYLNrmwOOHLhXcTmy5rQQ5u2HI5y64tS6fnKxxozA2gPaVro5+W5e3WtpSDGdd2NkPDzrMMmwYFEv4Tw9ooUfaJhXhq7AJakK/nTfpLquL9XSia8af+aOzx/p1v25f56dESlhNzcSlREP52hTA9T3foCA2IBkDitBeeGhUeeerQdczoRFxxSjoI244bPwAZ+tKIwO0XFaxLyd3jjzlya0F9w1N7wN0ZO4hY1NVv7oaYTUcU7TnvqGEMGLZpQBnIn7DCrUjKeW4AIUGvxcCP+F16lqFkuLSCgOAHM59NECVwBAOPGDk="
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJdbU8l66hVUAqk900GmEme5uhWcs05JMUQv2eD0j7MI juuso@starlabs"
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOdsfK46X5IhxxEy81am6A8YnHo2rcF2qZ75cHOKG7ToAAAACHNzaDprYXJp ssh:kari"
      ];
      privateKeyFile = sshKeysPath;
    };

    # Wireguard options
    vpn.wireguard = {
      enable = true;
      configFile = "/var/mnt/ssd/secrets/wg0.conf";
    };

  };

  systemd.services.lighthouse = {
    enable = true;

    description = "holesky cl";
    requires = [ "wg-quick-wg0.service" ];
    after = [ "wg-quick-wg0.service" ];

    script = ''${pkgs.lighthouse}/bin/lighthouse bn \
      --network holesky \
      --execution-endpoint http://localhost:8551 \
      --execution-jwt ${config.age.secrets."holesky-jwt".path} \
      --checkpoint-sync-url https://holesky.beaconstate.ethstaker.cc/ \
      --http \
      --datadir /var/mnt/ssd/ethereum/holesky/lighthouse \
      --builder http://127.0.0.1:18550 \
      --metrics
    '';

    wantedBy = [ "multi-user.target" ];
  };

  systemd.services.geth = {
    enable = true;

    description = "holesky el";
    requires = [ "wg-quick-wg0.service" ];
    after = [ "wg-quick-wg0.service" ];

    script = ''${pkgs.geth}/bin/geth \
      --datadir /var/mnt/ssd/ethereum/holesky/geth \
      --http --http.addr 192.168.100.50 --http.api="engine,eth,web3,net,debug" --http.port 8545 \
      --ws --ws.api="engine,eth,web3,net,debug" \
      --http.corsdomain "*" \
      --http.vhosts "*" \
      --holesky \
      --authrpc.jwtsecret=${config.age.secrets."holesky-jwt".path} \
      --metrics \
      --metrics.addr 127.0.0.1 \
      --maxpeers 100
    '';

    wantedBy = [ "multi-user.target" ];
  };

  systemd.services.mev-boost = {
    enable = true;

    description = "holesky mev";
    requires = [ "wg-quick-wg0.service" ];
    after = [ "wg-quick-wg0.service" ];

    script = ''${pkgs.mev-boost}/bin/mev-boost \
      -holesky \
      -addr 127.0.0.1:18550 \
      -relay-check \
      -relays "https://0x821f2a65afb70e7f2e820a925a9b4c80a159620582c1766b1b09729fec178b11ea22abb3a51f07b288be815a1a2ff516@bloxroute.holesky.blxrbdn.com,https://0xaa58208899c6105603b74396734a6263cc7d947f444f396a90f7b7d3e65d102aec7e5e5291b27e08d02c50a050825c2f@holesky.titanrelay.xyz,https://0xab78bf8c781c58078c3beb5710c57940874dd96aef2835e7742c866b4c7c0406754376c2c8285a36c630346aa5c5f833@holesky.aestus.live,https://0xafa4c6985aa049fb79dd37010438cfebeb0f2bd42b115b89dd678dab0670c1de38da0c4e9138c9290a398ecd9a0b3110@boost-relay-holesky.flashbots.net,https://0xb1559beef7b5ba3127485bbbb090362d9f497ba64e177ee2c8e7db74746306efad687f2cf8574e38d70067d40ef136dc@relay-stag.ultrasound.money"
    '';

    wantedBy = [ "multi-user.target" ];
  };

  systemd.services.ssvnode =
    let
      c = pkgs.writeText "config.yaml" ''
        global:
          LogFileBackups: 28
          LogFilePath: /var/mnt/ssd/ethereum/holesky/ssvnode/debug.log
          LogLevel: info

        db:
          Path: /var/mnt/ssd/ethereum/holesky/ssvnode/db

        ssv:
          Network: holesky
          ValidatorOptions:
            BuilderProposals: true

        eth2:
          BeaconNodeAddr: http://localhost:5052

        eth1:
          ETH1Addr: ws://localhost:8546

        p2p:
          # Optionally provide the external IP address of the node, if it cannot be automatically determined.
          # HostAddress: 192.168.1.1

          # Optionally override the default TCP & UDP ports of the node.
          # TcpPort: 13001
          # UdpPort: 12001

        KeyStore:
          PrivateKeyFile: ${config.sops.secrets."holesky/ssvnode/privateKey".path}
          PasswordFile: ${config.sops.secrets."holesky/ssvnode/password".path}

        MetricsAPIPort: 15000
      '';
    in
    {
      enable = true;

      description = "holesky ssvnode";

      serviceConfig = {
        Restart = "on-failure";
        RestartSec = 5;
      };

      script = ''${pkgs.ssvnode}/bin/ssvnode start-node -c ${c}'';

      wantedBy = [ "multi-user.target" ];
    };

  systemd.network = {
    enable = true;
    networks = {
      "10-wan" = {
        linkConfig.RequiredForOnline = "routable";
        matchConfig.Name = "enp6s0";
        networkConfig = {
          DHCP = "ipv4";
          IPv6AcceptRA = true;
        };
        address = [ "192.168.1.25/24" ]; # static IP
      };
    };
  };
  networking = {
    firewall = {
      allowedTCPPorts = [
        # NAT routes
        13001 # SSV
        30303 # geth discovery
        9001 # lighthouse discovery

        # Internal
        50001 # electrs
        8545 # holesky RPC
      ];
      allowedUDPPorts = [
        12001
        30303
        51821
        9001

        50001
        8545
      ];
    };
    useDHCP = false;
  };

  services.netdata = {
    enable = true;
    configDir = {
      "health_alarm_notify.conf" = config.sops.secrets."netdata/health_alarm_notify.conf".path;
      "go.d/prometheus.conf" = pkgs.writeText "go.d/prometheus.conf" ''
        jobs:
          - name: ssv
            url: http://127.0.0.1:15000/metrics
          - name: ssv_health
            url: http://127.0.0.1:15000/health
          - name: geth
            url: http://127.0.0.1:6060/debug/metrics/prometheus
          - name: lighthouse
            url: http://127.0.0.1:5054/metrics
          - name: electrs
            url: http://127.0.0.1:4224/metrics
      '';
      "health.d/ssv_node_status" = pkgs.writeText "health.d/ssv_node_status.conf" ''
        alarm: jesse, juuso: ssv_node_status
        lookup: min -10s
        on: prometheus_ssv.ssv_node_status
        every: 10s
        warn: $this == 0
      '';
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/log/smartd 0755 netdata netdata -"
  ];
  services.smartd = {
    enable = true;
    extraOptions = [
      "-A /var/log/smartd/"
      "--interval=600"
    ];
  };

  age = {
    generators.jwt = { pkgs, ... }: "${pkgs.openssl}/bin/openssl rand -hex 32";
    rekey = {
      agePlugins = [ pkgs.age-plugin-fido2-hmac ];
      hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF2U2OFXrH4ZT3gSYrTK6ZNkXTfGZQ5BhLh4cBelzzMF";
    };
    secrets = {
      holesky-jwt = {
        rekeyFile = ./secrets/agenix/holesky-jwt.age;
        generator.script = "jwt";
      };
    };
  };
  sops = {
    defaultSopsFile = ./secrets/default.yaml;
    secrets."netdata/health_alarm_notify.conf" = {
      owner = "netdata";
      group = "netdata";
    };
    secrets."holesky/ssvnode/password" = { };
    secrets."holesky/ssvnode/privateKey" = { };
    secrets."holesky/ssvnode/publicKey" = { };
    age.sshKeyPaths = [ sshKeysPath ];
  };

  wirenix = {
    enable = true;
    peerName = "kaakkuri"; # defaults to hostname otherwise
    configurer = "networkd"; # defaults to "static", could also be "networkd"
    keyProviders = [ "agenix-rekey" ]; # could also be ["agenix-rekey"] or ["acl" "agenix-rekey"]
    secretsDir = ../../nixosModules/wirenix/agenix; # only if you're using agenix-rekey
    aclConfig = import ../../nixosModules/wirenix/acl.nix;
  };

  services.etcd =
    let
      inherit (inputs.clib.lib.network.ipv6) fromString;
      self = map (x: x.address) (map fromString config.systemd.network.networks."50-simple".address);
      clusterAddr = map (node: "${node.wirenix.peerName}=${toString (map (wg: "http://[${wg.address}]") (map fromString node.systemd.network.networks."50-simple".address))}:2380");
      kaakkuri = clusterAddr [ outputs.nixosConfigurations."kaakkuri-ephemeral-alpha".config ];
      node1 = clusterAddr [ outputs.nixosConfigurations."hetzner-ephemeral-alpha".config ];
      node2 = clusterAddr [ outputs.nixosConfigurations."ponkila-ephemeral-beta".config ];
    in
    {
      enable = true;
      name = config.wirenix.peerName;
      listenPeerUrls = map (x: "http://[${x}]:2380") self;
      listenClientUrls = map (x: "http://[${x}]:2379") self;
      initialClusterToken = "etcd-cluster-1";
      initialClusterState = "new";
      initialCluster = kaakkuri ++ node1 ++ node2;
      dataDir = "/var/mnt/ssd/etcd";
      openFirewall = true;
    };

  system.stateVersion = "24.05";
}
```

We can now build the whole image by running `nix build .#kaakkuri-ephemeral-alpha`.
The produced files can be put into a PXE server, to ensure that the node loads the operating system at bootup using the router.

An alternative is to just apply this configuration from a development machine as such: `nixos-rebuild test --flake .#kaakkuri-ephemeral-alpha --target-host core@192.168.100.50 --use-remote-sudo`

This will build all the software locally, then transport the packages over ssh, and then initiate nixos switch command on the host.
