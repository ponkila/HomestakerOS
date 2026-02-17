{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.homestakeros;
in
{
  inherit (import ./options.nix { inherit lib pkgs cfg; }) options;

  config = with lib; let
    # Function to check if a path is on a persistent mount
    isPersistentPath = path:
      let
        mountsOnPath = lib.filterAttrs
          (_name: mount:
            mount.enable &&
            lib.hasPrefix mount.where path &&
            !(lib.elem mount.type [ "tmpfs" "overlay" "squashfs" ])
          )
          cfg.mounts;
      in
      mountsOnPath != { };

    # Function to parse a URL into its components
    parseEndpoint = endpoint:
      let
        regex = "(https?://)?([^:/]+):([0-9]+)(/.*)?$";
        match = builtins.match regex endpoint;
      in
      {
        addr = builtins.elemAt match 1;
        port = builtins.elemAt match 2;
      };

    # Function to generate VPN client interface name from config file path
    getVpnInterfaceName = VPNserviceName: builtins.elemAt (builtins.split "[.]" (builtins.baseNameOf cfg.vpn.${VPNserviceName}.configFile)) 0;

    # Function to get the active client
    getActiveClients = clients: path: builtins.filter (serviceName: path.${serviceName}.enable) clients;

    activeConsensusClients = getActiveClients (builtins.attrNames cfg.consensus) cfg.consensus;
    activeExecutionClients = getActiveClients (builtins.attrNames cfg.execution) cfg.execution;
    activeVPNClients = getActiveClients (builtins.attrNames cfg.vpn) cfg.vpn;

    # Function to create a service
    createService = serviceName: serviceType: execStart: parsedEndpoint: allowedPorts:
      mkIf cfg.${serviceType}.${serviceName}.enable {
        environment.systemPackages = [
          pkgs.${serviceName}
        ];

        # Service configuration
        systemd.services.${serviceName} = {
          enable = true;

          description = "${serviceType}, mainnet";
          requires =
            lib.optional (elem "wireguard" activeVPNClients)
              "wg-quick-${getVpnInterfaceName "wireguard"}.service";

          after =
            (
              if serviceType == "execution"
              then map (name: "${name}.service") activeConsensusClients
              else if serviceType == "consensus" && cfg.addons.mev-boost.enable
              then [ "mev-boost.service" ]
              else [ ]
            )
            ++ lib.optional (elem "wireguard" activeVPNClients)
              "wg-quick-${getVpnInterfaceName "wireguard"}.service";

          serviceConfig = {
            ExecStart = concatStringsSep " \\\n\t" execStart;
            Restart = "always";
            RestartSec = "5s";
            Type = "simple";
          };

          wantedBy = [ "multi-user.target" ];
        };

        # Firewall
        networking.firewall = {
          allowedTCPPorts = allowedPorts;
          allowedUDPPorts = allowedPorts;

          # Function to allow ports for each of the enabled VPN clients
          interfaces = builtins.listToAttrs (map
            (VPNserviceName: {
              name = "${getVpnInterfaceName VPNserviceName}";
              value = {
                allowedTCPPorts =
                  if serviceType == "consensus"
                  then [ (lib.strings.toInt parsedEndpoint.port) ]
                  else if serviceType == "execution"
                  then [ 8545 8546 ] # json-rpc / websockets
                  else [ ];
              };
            })
            activeVPNClients);
        };
      };
  in
  mkMerge [
    ################################################################### LOCALIZATION
    (
      mkIf true {
        networking.hostName = cfg.localization.hostname;
        time.timeZone = cfg.localization.timezone;
      }
    )

    #################################################################### MOUNTS
    # cfg: https://www.freedesktop.org/software/systemd/man/systemd.mount.html#Options
    (
      mkIf true {
        systemd.mounts = lib.mapAttrsToList (_mountName: mountCfg: mountCfg) cfg.mounts;
      }
    )

    #################################################################### SSH (system level)
    (
      mkIf true {
        services.openssh = {
          enable = true;
          hostKeys = [
            {
              path = cfg.ssh.privateKeyFile;
              type = "ed25519";
            }
          ];
          allowSFTP = false;
          extraConfig = ''
            AllowTcpForwarding yes
            X11Forwarding no
            #AllowAgentForwarding no
            AllowStreamLocalForwarding no
            AuthenticationMethods publickey
          '';
          settings.PasswordAuthentication = false;
          settings.KbdInteractiveAuthentication = false;
        };
      }
    )

    #################################################################### USER (core)
    (
      mkIf true {
        users.users.core = {
          isNormalUser = true;
          group = "core";
          extraGroups = [ "wheel" ];
          openssh.authorizedKeys.keys = cfg.ssh.authorizedKeys;
          shell = pkgs.fish;
        };
        users.groups.core = { };
        environment.shells = [ pkgs.fish ];

        programs = {
          tmux.enable = true;
          htop.enable = true;
          git.enable = true;
          fish.enable = true;
          fish.loginShellInit = "fish_add_path --move --prepend --path $HOME/.nix-profile/bin /run/wrappers/bin /etc/profiles/per-user/$USER/bin /run/current-system/sw/bin /nix/var/nix/profiles/default/bin";
        };
      }
    )

    #################################################################### MOTD (no options)
    # cfg: https://github.com/rust-motd/rust-motd
    (
      mkIf true {
        programs.rust-motd = {
          enable = true;
          enableMotdInSSHD = true;
          settings = {
            banner = {
              color = "yellow";
              command = ''
                echo ""
                echo " +-------------+"
                echo " | 10110 010   |"
                echo " | 101 101 10  |"
                echo " | 0   _____   |"
                echo " |    / ___ \  |"
                echo " |   / /__/ /  |"
                echo " +--/ _____/---+"
                echo "   / /"
                echo "  /_/"
                echo ""
                systemctl --failed --quiet
              '';
            };
            uptime.prefix = "Uptime:";
            last_login.core = 2;
          };
        };
      }
    )

    #################################################################### SSV
    # cfg: https://docs.ssv.network/run-a-node/operator-node/installation#create-configuration-file
    # https://github.com/bloxapp/ssv/issues/1138
    (
      mkIf
        (
          pkgs.system == "x86_64-linux"
          && length activeConsensusClients > 0
          && length activeExecutionClients > 0
          && isPersistentPath cfg.addons.ssv-node.dataDir
        )
        {
          systemd.services.ssv-node =
            let
              privateKeyFile = "${cfg.addons.ssv-node.dataDir}/ssv_operator_key";
              publicKeyFile = "${cfg.addons.ssv-node.dataDir}/ssv_operator_key.pub";
              privateKeyPasswordFile = "${cfg.addons.ssv-node.dataDir}/password";

              # TODO: This is a bad way to do this, prevents multiple instances
              executionClient = builtins.elemAt activeExecutionClients 0;
              consensusClient = builtins.elemAt activeConsensusClients 0;
              parsedExecutionEndpoint = parseEndpoint cfg.execution.${executionClient}.endpoint;

              ssvConfig = pkgs.writeText "config.yaml" ''
                global:
                  LogLevel: info
                  LogFilePath: ${cfg.addons.ssv-node.dataDir}/debug.log

                db:
                  Path: ${cfg.addons.ssv-node.dataDir}/db

                ssv:
                  Network: mainnet
                  ValidatorOptions:
                    BuilderProposals: true

                eth2:
                  BeaconNodeAddr: ${cfg.consensus.${consensusClient}.endpoint}
                  Network: mainnet

                eth1:
                  # This assumes that the websocket is bind to the same port, true for erigon, not for others
                  # TODO: Consider having a variable name for websocket endpoint
                  ETH1Addr: ws://${parsedExecutionEndpoint.addr}:8546

                KeyStore:
                  PrivateKeyFile: ${privateKeyFile}
                  PasswordFile: ${privateKeyPasswordFile}
              '';
            in
            {
              description = "Operator node for Secret Shared Validators (SSV)";
              after = [ "network-online.target" ];
              wants = [ "network-online.target" ];
              wantedBy = [ "multi-user.target" ];

              script =
                let
                  curl = "${pkgs.curl}/bin/curl";
                  jq = "${pkgs.jq}/bin/jq";
                in
                ''
                  mkdir -p ${cfg.addons.ssv-node.dataDir}

                  # Check if keys exist
                  if [ ! -f "${privateKeyFile}" ] || [ ! -f "${publicKeyFile}" ]; then
                    # Generate keys with timestamp as a password
                    ${pkgs.init-ssv}/bin/init-ssv \
                      --private-key "${privateKeyFile}" \
                      --public-key "${publicKeyFile}" \
                      --password-file "${privateKeyPasswordFile}" \
                      $(date +%s) || exit 1
                  fi

                  # Start the node if operator is registered
                  SSV_PUBLIC_KEY=$(cat "${publicKeyFile}")
                  if ${curl} -s "https://api.ssv.network/api/v4/mainnet/operators/public_key/$SSV_PUBLIC_KEY" | ${jq} -e '.data != null' > /dev/null; then
                    echo "operator is registered, starting ssv node..."
                    ${pkgs.ssvnode}/bin/ssvnode start-node --config ${ssvConfig}
                  else
                    echo "error: operator is not registered yet, exiting"
                    exit 1
                  fi
                '';
              serviceConfig = {
                Type = "simple";
                Restart = "on-failure";
                RestartSec = "600s"; # 10 minutes
              };
            };

          # Firewall
          networking.firewall = {
            allowedTCPPorts = [ 13001 ];
            allowedUDPPorts = [ 12001 ];
          };
        }
    )

    #################################################################### WIREGUARD
    # cfg: https://man7.org/linux/man-pages/man8/wg.8.html
    (
      mkIf cfg.vpn.wireguard.enable {
        networking.wg-quick.interfaces.${getVpnInterfaceName "wireguard"}.configFile = cfg.vpn.wireguard.configFile;
      }
    )

    #################################################################### ERIGON
    # cli: https://erigon.gitbook.io/erigon/advanced-usage/command-line-options
    # sec: https://erigon.gitbook.io/erigon/basic-usage/default-ports-and-firewalls
    (
      let
        serviceName = "erigon";
        serviceType = "execution";

        parsedEndpoint = parseEndpoint cfg.execution.erigon.endpoint;
        execStart = [
          "${pkgs.erigon}/bin/erigon"
          "--datadir ${cfg.execution.erigon.dataDir}"
          "--chain mainnet"
          "--metrics"
          # auth for consensus client
          "--authrpc.vhosts \"*\""
          "--authrpc.port ${parsedEndpoint.port}"
          "--authrpc.addr ${parsedEndpoint.addr}"
          "--authrpc.jwtsecret ${cfg.execution.erigon.jwtSecretFile}"
          # json-rpc for interacting
          "--http.addr=${parsedEndpoint.addr}"
          "--http.api=eth,erigon,web3,net,debug,trace,txpool"
          "--http.corsdomain=\"*\""
          "--http.port=8545"
          "--private.api.addr=localhost:9090"
          "--txpool.api.addr=localhost:9090"
          # ws for ssv
          "--ws"
        ]
        ++ cfg.execution.erigon.extraOptions;
        allowedPorts = [ 30303 30304 42069 ];
      in
      createService serviceName serviceType execStart parsedEndpoint allowedPorts
    )

    #################################################################### GETH
    # cli: https://geth.ethereum.org/docs/fundamentals/command-line-options
    # sec: https://geth.ethereum.org/docs/fundamentals/security
    (
      let
        serviceName = "geth";
        serviceType = "execution";

        parsedEndpoint = parseEndpoint cfg.execution.geth.endpoint;
        execStart = [
          "${pkgs.go-ethereum}/bin/geth"
          "--mainnet"
          "--datadir ${cfg.execution.geth.dataDir}"
          "--metrics"
          # auth for consensus client
          "--authrpc.vhosts \"*\""
          "--authrpc.port ${parsedEndpoint.port}"
          "--authrpc.addr ${parsedEndpoint.addr}"
          "--authrpc.jwtsecret ${cfg.execution.geth.jwtSecretFile}"
          # json-rpc for interacting
          "--http.addr=${parsedEndpoint.addr}"
          "--http.api=eth,web3,net,debug,txpool"
          "--http.corsdomain=\"*\""
          "--http.port=8545"
          "--http"
          # ws for ssv
          "--ws.addr=${parsedEndpoint.addr}"
          "--ws.api=eth,web3,net,debug,txpool"
          "--ws.origins=\"*\""
          "--ws.port=8545"
          "--ws"
        ]
        ++ cfg.execution.geth.extraOptions;
        allowedPorts = [ 30303 ];
      in
      createService serviceName serviceType execStart parsedEndpoint allowedPorts
    )

    #################################################################### NETHERMIND
    # cli: https://docs.nethermind.io/nethermind/ethereum-client/configuration
    # sec: https://docs.nethermind.io/nethermind/first-steps-with-nethermind/firewall-configuration
    (
      let
        serviceName = "nethermind";
        serviceType = "execution";

        parsedEndpoint = parseEndpoint cfg.execution.nethermind.endpoint;
        execStart = [
          "${pkgs.nethermind}/bin/Nethermind.Runner"
          "--config mainnet"
          "--datadir ${cfg.execution.nethermind.dataDir}"
          "--Metrics.Enabled true"
          # auth for consensus client
          "--JsonRpc.EngineHost ${parsedEndpoint.addr}"
          "--JsonRpc.EnginePort ${parsedEndpoint.port}"
          "--JsonRpc.JwtSecretFile ${cfg.execution.nethermind.jwtSecretFile}"
          # json-rpc for interacting
          "--JsonRpc.Enabled true"
          "--JsonRpc.Host ${parsedEndpoint.addr}"
          "--JsonRpc.Port 8545"
          # ws for ssv
          "--Init.WebSocketsEnabled true"
          "--JsonRpc.WebSocketsPort 8545"
        ]
        ++ cfg.execution.nethermind.extraOptions;
        allowedPorts = [ 30303 ];
      in
      createService serviceName serviceType execStart parsedEndpoint allowedPorts
    )

    #################################################################### BESU
    # cli: https://besu.hyperledger.org/stable/public-networks/reference/cli/options
    # sec: https://besu.hyperledger.org/stable/public-networks/how-to/connect/configure-ports
    (
      let
        serviceName = "besu";
        serviceType = "execution";

        parsedEndpoint = parseEndpoint cfg.execution.besu.endpoint;
        execStart = [
          "${pkgs.besu}/bin/besu"
          "--network=mainnet"
          "--data-path=${cfg.execution.besu.dataDir}"
          "--metrics-enabled=true"
          # auth for consensus client
          "--engine-rpc-enabled=true"
          "--engine-host-allowlist=\"*\""
          "--engine-rpc-port=${parsedEndpoint.port}"
          "--rpc-http-host=${parsedEndpoint.addr}"
          "--engine-jwt-secret=${cfg.execution.besu.jwtSecretFile}"
          # json-rpc for interacting
          "--rpc-http-api=ETH,NET,WEB3,TRACE,TXPOOL,DEBUG"
          "--rpc-http-authentication-enabled=false"
          "--rpc-http-cors-origins=\"*\""
          "--rpc-http-enabled=true"
          "--rpc-http-port=8545"
          # ws for ssv
          "--rpc-ws-api=ETH,NET,WEB3,TRACE,TXPOOL,DEBUG"
          "--rpc-ws-authentication-enabled=false"
          "--rpc-ws-enabled=true"
          "--rpc-ws-host=${parsedEndpoint.addr}"
          "--rpc-ws-port=8546"
        ]
        ++ cfg.execution.besu.extraOptions;
        allowedPorts = [ 30303 ];
      in
      createService serviceName serviceType execStart parsedEndpoint allowedPorts
    )

    #################################################################### MEV-BOOST
    # cli: https://github.com/flashbots/mev-boost#mev-boost-cli-arguments
    (
      let
        serviceName = "mev-boost";
        serviceType = "addons";

        parsedEndpoint = parseEndpoint cfg.addons.mev-boost.endpoint;
        execStart = [
          "${pkgs.mev-boost}/bin/mev-boost"
          "-mainnet"
          "-relay-check"
          "-relays ${lib.concatStringsSep "," [
              "https://0xa1559ace749633b997cb3fdacffb890aeebdb0f5a3b6aaa7eeeaf1a38af0a8fe88b9e4b1f61f236d2e64d95733327a62@relay.ultrasound.money"
              "https://0xa15b52576bcbf1072f4a011c0f99f9fb6c66f3e1ff321f11f461d15e31b1cb359caa092c71bbded0bae5b5ea401aab7e@aestus.live"
              "https://0xa7ab7a996c8584251c8f925da3170bdfd6ebc75d50f5ddc4050a6fdc77f2a3b5fce2cc750d0865e05d7228af97d69561@agnostic-relay.net"
            ]}"
          "-addr ${parsedEndpoint.addr}:${parsedEndpoint.port}"
        ]
        ++ cfg.addons.mev-boost.extraOptions;
        allowedPorts = [ ];
      in
      createService serviceName serviceType execStart parsedEndpoint allowedPorts
    )

    #################################################################### LIGHTHOUSE
    # cli: https://lighthouse-book.sigmaprime.io/api-bn.html
    # sec: https://lighthouse-book.sigmaprime.io/advanced_networking.html
    (
      let
        serviceName = "lighthouse";
        serviceType = "consensus";

        parsedEndpoint = parseEndpoint cfg.consensus.lighthouse.endpoint;
        execStart = [
          "${pkgs.lighthouse}/bin/lighthouse bn"
          "--datadir ${cfg.consensus.lighthouse.dataDir}"
          "--network mainnet"
          "--http"
          "--http-address ${parsedEndpoint.addr}"
          "--http-port ${parsedEndpoint.port}"
          "--http-allow-origin \"*\""
          "--execution-endpoint ${cfg.consensus.lighthouse.execEndpoint}"
          "--execution-jwt ${cfg.consensus.lighthouse.jwtSecretFile}"
          (
            if cfg.consensus.lighthouse.slasher.enable
            then
              "--slasher \\\n\t"
                + "--slasher-history-length "
                + (toString cfg.consensus.lighthouse.slasher.historyLength)
                + " \\\n\t"
                + "--slasher-max-db-size "
                + (toString cfg.consensus.lighthouse.slasher.maxDatabaseSize)
            else ""
          )
          (
            if cfg.addons.mev-boost.enable
            then "--builder ${cfg.addons.mev-boost.endpoint}"
            else ""
          )
          "--metrics"
          "--checkpoint-sync-url \"https://beaconstate.info\""
        ]
        ++ cfg.consensus.lighthouse.extraOptions;
        allowedPorts = [ 9000 9001 ];
      in
      createService serviceName serviceType execStart parsedEndpoint allowedPorts
    )

    #################################################################### PRYSM
    # cli: https://docs.prylabs.network/docs/prysm-usage/parameters
    # sec: https://docs.prylabs.network/docs/prysm-usage/p2p-host-ip
    (
      let
        serviceName = "prysm";
        serviceType = "consensus";

        parsedEndpoint = parseEndpoint cfg.consensus.prysm.endpoint;
        execStart = [
          "${pkgs.prysm}/bin/beacon-chain"
          "--datadir ${cfg.consensus.prysm.dataDir}"
          "--mainnet"
          "--grpc-gateway-host ${parsedEndpoint.addr}"
          "--grpc-gateway-port ${parsedEndpoint.port}"
          "--execution-endpoint ${cfg.consensus.prysm.execEndpoint}"
          "--jwt-secret ${cfg.consensus.prysm.jwtSecretFile}"
          (
            if cfg.addons.mev-boost.enable
            then "--http-mev-relay ${cfg.addons.mev-boost.endpoint}"
            else ""
          )
          (
            if cfg.consensus.prysm.slasher.enable
            then
              "--historical-slasher-node \\\n\t"
                + "--slasher-datadir ${cfg.consensus.prysm.dataDir}/beacon/slasher_db"
            else ""
          )
          "--accept-terms-of-use"
          "--checkpoint-sync-url=https://beaconstate.info"
          "--genesis-beacon-api-url=https://beaconstate.info"
        ]
        ++ cfg.consensus.prysm.extraOptions;
        allowedPorts = [ 9000 ];
      in
      createService serviceName serviceType execStart parsedEndpoint allowedPorts
    )

    #################################################################### TEKU
    # cli: https://docs.teku.consensys.net/reference/cli
    (
      let
        serviceName = "teku";
        serviceType = "consensus";

        parsedEndpoint = parseEndpoint cfg.consensus.teku.endpoint;
        execStart = [
          "${pkgs.teku}/bin/teku"
          "--data-base-path=${cfg.consensus.teku.dataDir}"
          "--network=mainnet"
          "--rest-api-enabled=true"
          "--rest-api-port=${parsedEndpoint.port}"
          "--rest-api-interface=${parsedEndpoint.addr}"
          "--rest-api-host-allowlist=\"*\""
          "--ee-endpoint=${cfg.consensus.teku.execEndpoint}"
          "--ee-jwt-secret-file=${cfg.consensus.teku.jwtSecretFile}"
          (
            if cfg.addons.mev-boost.enable
            then "--builder-endpoint=${cfg.addons.mev-boost.endpoint}"
            else ""
          )
          "--metrics-enabled=true"
        ]
        ++ cfg.consensus.teku.extraOptions;
        allowedPorts = [ 9000 ];
      in
      createService serviceName serviceType execStart parsedEndpoint allowedPorts
    )

    #################################################################### NIMBUS
    # cli: https://nimbus.guide/options.html
    (
      let
        serviceName = "nimbus";
        serviceType = "consensus";

        parsedEndpoint = parseEndpoint cfg.consensus.nimbus.endpoint;
        execStart = [
          "${pkgs.nimbus}/bin/nimbus_beacon_node"
          "--data-dir=${cfg.consensus.nimbus.dataDir}"
          "--network=mainnet"
          "--rest=true"
          "--rest-port=${parsedEndpoint.port}"
          "--rest-address=${parsedEndpoint.addr}"
          "--rest-allow-origin=\"*\""
          "--el=${cfg.consensus.nimbus.execEndpoint}"
          "--jwt-secret=${cfg.consensus.nimbus.jwtSecretFile}"
          (
            if cfg.addons.mev-boost.enable
            then
              "--payload-builder=true \\\n\t"
                + "--payload-builder-url=${cfg.addons.mev-boost.endpoint}"
            else ""
          )
          "--metrics=true"
        ]
        ++ cfg.consensus.nimbus.extraOptions;
        allowedPorts = [ 9000 ];
      in
      createService serviceName serviceType execStart parsedEndpoint allowedPorts
    )
  ];
}
