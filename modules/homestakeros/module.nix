{
  config,
  lib,
  pkgs,
  inputs,
  outputs,
  ...
}: let
  cfg = config.homestakeros;
in {
  inherit (import ./options.nix {inherit lib pkgs;}) options;

  config = with lib; let
    # Function to parse a URL into its components
    parseEndpoint = endpoint: let
      regex = "(https?://)?([^:/]+):([0-9]+)(/.*)?$";
      match = builtins.match regex endpoint;
    in {
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
      mkIf (cfg.${serviceType}.${serviceName}.enable) {
        environment.systemPackages = [
          pkgs.${serviceName}
        ];

        # Service configuration
        systemd.services.${serviceName} = {
          enable = true;

          description = "${serviceType}, mainnet";
          requires =
            []
            ++ lib.optional (elem "wireguard" activeVPNClients)
            "wg-quick-${getVpnInterfaceName "wireguard"}.service";

          after =
            (
              if serviceType == "execution"
              then map (name: "${name}.service") activeConsensusClients
              else if serviceType == "consensus" && cfg.addons.mev-boost.enable
              then ["mev-boost.service"]
              else []
            )
            ++ lib.optional (elem "wireguard" activeVPNClients)
            "wg-quick-${getVpnInterfaceName "wireguard"}.service";

          serviceConfig = {
            ExecStart = concatStringsSep " \\\n\t" execStart;
            Restart = "always";
            RestartSec = "5s";
            Type = "simple";
          };

          wantedBy = ["multi-user.target"];
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
                  then [(lib.strings.toInt parsedEndpoint.port)]
                  else if serviceType == "execution"
                  then [8545 8546] # json-rpc / websockets
                  else [];
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
          systemd.mounts =
            lib.mapAttrsToList
            (name: mount: {
              enable = mount.enable or true;
              description = mount.description or "${name} mount point";
              what = mount.what;
              where = mount.where;
              type = mount.type or "ext4";
              options = mount.options or "defaults";
              before = lib.mkDefault (mount.before or []);
              wantedBy = mount.wantedBy or ["multi-user.target"];
            })
            cfg.mounts;
        }
      )

      #################################################################### SSH (system level)
      (
        mkIf true {
          services.openssh = {
            enable = true;
            hostKeys = lib.mkIf (cfg.ssh.privateKeyFile != null) [
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
            extraGroups = ["wheel"];
            openssh.authorizedKeys.keys = cfg.ssh.authorizedKeys;
            shell = pkgs.fish;
          };
          users.groups.core = {};
          environment.shells = [pkgs.fish];

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
          cfg.addons.ssv-node.privateKeyFile
          != null
          && cfg.addons.ssv-node.privateKeyPasswordFile
          != null
          && pkgs.system == "x86_64-linux"
          && length activeConsensusClients > 0
          && length activeExecutionClients > 0
        )
        {
          systemd.services.ssv-autostart = let
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
                PrivateKeyFile: ${cfg.addons.ssv-node.privateKeyFile}
                PasswordFile: ${cfg.addons.ssv-node.privateKeyPasswordFile}
            '';
          in {
            description = "Start the SSV node if the private operator key exists";
            unitConfig.ConditionPathExists = [
              "${cfg.addons.ssv-node.privateKeyFile}"
              "${cfg.addons.ssv-node.privateKeyPasswordFile}"
            ];
            # The operator key is defined here, so it does not need to be evaluated
            script = ''
              ${pkgs.ssvnode}/bin/ssvnode start-node --config ${ssvConfig}
            '';
            wantedBy = ["multi-user.target"];
            serviceConfig = {
              Restart = "always";
              RestartSec = "5s";
              Type = "simple";
            };
          };
          systemd.timers.ssv-autostart = {
            timerConfig.OnBootSec = "10min";
            wantedBy = ["timers.target"];
          };
          # Firewall
          networking.firewall = {
            allowedTCPPorts = [13001];
            allowedUDPPorts = [12001];
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
            (
              if cfg.execution.erigon.jwtSecretFile != null
              then "--authrpc.jwtsecret ${cfg.execution.erigon.jwtSecretFile}"
              else ""
            )
            # json-rpc for interacting
            "--http.addr=${parsedEndpoint.addr}"
            "--http.api=eth,erigon,web3,net,debug,trace,txpool"
            "--http.corsdomain=\"*\""
            "--http.port=8545"
            "--private.api.addr=localhost:9090"
            "--txpool.api.addr=localhost:9090"
            # ws for ssv
            "--ws"
          ];
          allowedPorts = [30303 30304 42069];
        in (createService serviceName serviceType execStart parsedEndpoint allowedPorts)
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
            (
              if cfg.execution.geth.jwtSecretFile != null
              then "--authrpc.jwtsecret ${cfg.execution.geth.jwtSecretFile}"
              else ""
            )
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
          ];
          allowedPorts = [30303];
        in (createService serviceName serviceType execStart parsedEndpoint allowedPorts)
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
            (
              if cfg.execution.nethermind.jwtSecretFile != null
              then "--JsonRpc.JwtSecretFile ${cfg.execution.nethermind.jwtSecretFile}"
              else ""
            )
            # json-rpc for interacting
            "--JsonRpc.Enabled true"
            "--JsonRpc.Host ${parsedEndpoint.addr}"
            "--JsonRpc.Port 8545"
            # ws for ssv
            "--Init.WebSocketsEnabled true"
            "--JsonRpc.WebSocketsPort 8545"
          ];
          allowedPorts = [30303];
        in (createService serviceName serviceType execStart parsedEndpoint allowedPorts)
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
            (
              if cfg.execution.besu.jwtSecretFile != null
              then "--engine-jwt-secret=${cfg.execution.besu.jwtSecretFile}"
              else ""
            )
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
          ];
          allowedPorts = [30303];
        in (createService serviceName serviceType execStart parsedEndpoint allowedPorts)
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
              "https://0xac6e77dfe25ecd6110b8e780608cce0dab71fdd5ebea22a16c0205200f2f8e2e3ad3b71d3499c54ad14d6c21b41a37ae@boost-relay.flashbots.net"
              "https://0xad0a8bb54565c2211cee576363f3a347089d2f07cf72679d16911d740262694cadb62d7fd7483f27afd714ca0f1b9118@bloxroute.ethical.blxrbdn.com"
              "https://0x9000009807ed12c1f08bf4e81c6da3ba8e3fc3d953898ce0102433094e5f22f21102ec057841fcb81978ed1ea0fa8246@builder-relay-mainnet.blocknative.com"
              "https://0xb0b07cd0abef743db4260b0ed50619cf6ad4d82064cb4fbec9d3ec530f7c5e6793d9f286c4e082c0244ffb9f2658fe88@bloxroute.regulated.blxrbdn.com"
              "https://0x8b5d2e73e2a3a55c6c87b8b6eb92e0149a125c852751db1422fa951e42a09b82c142c3ea98d0d9930b056a3bc9896b8f@bloxroute.max-profit.blxrbdn.com"
              "https://0x98650451ba02064f7b000f5768cf0cf4d4e492317d82871bdc87ef841a0743f69f0f1eea11168503240ac35d101c9135@mainnet-relay.securerpc.com"
              "https://0xa1559ace749633b997cb3fdacffb890aeebdb0f5a3b6aaa7eeeaf1a38af0a8fe88b9e4b1f61f236d2e64d95733327a62@relay.ultrasound.money"
            ]}"
            "-addr ${parsedEndpoint.addr}:${parsedEndpoint.port}"
          ];
          allowedPorts = [];
        in (createService serviceName serviceType execStart parsedEndpoint allowedPorts)
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
            (
              if cfg.consensus.lighthouse.jwtSecretFile != null
              then "--execution-jwt ${cfg.consensus.lighthouse.jwtSecretFile}"
              else ""
            )
            "--prune-payloads false"
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
          ];
          allowedPorts = [9000 9001];
        in (createService serviceName serviceType execStart parsedEndpoint allowedPorts)
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
            (
              if cfg.consensus.prysm.jwtSecretFile != null
              then "--jwt-secret ${cfg.consensus.prysm.jwtSecretFile}"
              else ""
            )
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
          ];
          allowedPorts = [9000];
        in (createService serviceName serviceType execStart parsedEndpoint allowedPorts)
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
            (
              if cfg.consensus.teku.jwtSecretFile != null
              then "--ee-jwt-secret-file=${cfg.consensus.teku.jwtSecretFile}"
              else ""
            )
            (
              if cfg.addons.mev-boost.enable
              then "--builder-endpoint=${cfg.addons.mev-boost.endpoint}"
              else ""
            )
            "--metrics-enabled=true"
          ];
          allowedPorts = [9000];
        in (createService serviceName serviceType execStart parsedEndpoint allowedPorts)
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
          ];
          allowedPorts = [9000];
        in (createService serviceName serviceType execStart parsedEndpoint allowedPorts)
      )
    ];
}
