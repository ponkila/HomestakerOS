{ config, lib, pkgs, ... }:
let
  cfg = config.services.homestakeros-backend;
in
{
  options = {
    services.homestakeros-backend = {
      enable = lib.mkEnableOption "Whether to enable HomestakerOS backend.";

      port = lib.mkOption {
        type = lib.types.int;
        default = 8081;
        description = "The port on which to listen.";
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          If non-null, enables a Caddy reverse proxy with automatic SSL via ACME/Let's Encrypt.
          A DNS record (A, AAAA, or CNAME) must exist for the specified domain.
        '';
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Open the firewall port(s).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.homestakeros-backend = {
      description = "HomestakerOS backend service";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.backend}/bin/backend --port ${toString cfg.port} ${if cfg.domain != null then "--domain ${cfg.domain}" else ""}";
        Restart = "always";
        RestartSec = "5";
      };
    };

    # If a domain is provided, enable Caddy as a reverse proxy
    services.caddy = lib.mkIf (cfg.domain != null) {
      enable = true;
      virtualHosts."${cfg.domain}" = {
        useACMEHost = cfg.domain;
        extraConfig = ''
          reverse_proxy http://127.0.0.1:${toString cfg.port}
        '';
      };
    };

    # If a domain is provided, configure ACME certificate
    security.acme = lib.mkIf (cfg.domain != null) {
      acceptTerms = true;
      certs."${cfg.domain}" = {
        email = "homestakeros@ponkila.com";
        listenHTTP = ":1360";
        reloadServices = [ "caddy.service" ];

        # WARN: Using the staging environment to avoid hitting rate limits while testing
        server = "https://acme-staging-v02.api.letsencrypt.org/directory";
      };
    };

    # Open the required firewall ports
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ 80 443 cfg.port ];
  };
}
