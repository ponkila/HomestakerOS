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

      reverseProxy = lib.mkOption {
        type = lib.types.enum [ "none" "nginx" ];
        default = "none";
        description = "Which reverse proxy to use. Set to 'nginx' to enable the Nginx reverse proxy.";
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
        ExecStart = "${pkgs.backend}/bin/backend --port ${toString cfg.port}";
        Restart = "always";
        RestartSec = "5";
      };
    };

    # Reverse proxy using Nginx
    services.nginx = lib.mkIf (cfg.reverseProxy == "nginx") {
      enable = true;
      virtualHosts."localhost" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.port}";
        };
      };
    };

    # Open the required firewall ports
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (
      if cfg.reverseProxy != "none" then
        [ cfg.port 80 ]
      else
        [ cfg.port ]
    );
  };
}
