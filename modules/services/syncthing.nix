{ config, lib, pkgs, ... }:

with lib;

{
  meta.maintainers = [ maintainers.rycee ];

  options = {
    services.syncthing = {
      enable = mkEnableOption "Syncthing continuous file synchronization";

      tray = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to enable a syncthing tray service.";
        };

        package = mkOption {
          type = types.package;
          default = pkgs.syncthingtray-minimal;
          defaultText = literalExample "pkgs.syncthingtray-minimal";
          example = literalExample "pkgs.qsyncthingtray";
          description = "Syncthing tray package to use";
        };
      };
    };
  };

  config = mkMerge [
    (mkIf config.services.syncthing.enable {
      home.packages = [ (getOutput "man" pkgs.syncthing) ];

      systemd.user.services = {
        syncthing = {
          Unit = {
            Description =
              "Syncthing - Open Source Continuous File Synchronization";
            Documentation = "man:syncthing(1)";
            After = [ "network.target" ];
          };

          Service = {
            ExecStart =
              "${pkgs.syncthing}/bin/syncthing -no-browser -no-restart -logflags=0";
            Restart = "on-failure";
            SuccessExitStatus = [ 3 4 ];
            RestartForceExitStatus = [ 3 4 ];
          };

          Install = { WantedBy = [ "default.target" ]; };
        };
      };
    })

    (mkIf config.services.syncthing.tray.enable {
      systemd.user.services = {
        "${config.services.syncthing.tray.package.pname}" = {
          Unit = {
            Description = config.services.syncthing.tray.package.pname;
            After = [
              "graphical-session-pre.target"
              "polybar.service"
              "taffybar.service"
              "stalonetray.service"
            ];
            PartOf = [ "graphical-session.target" ];
          };

          Service = {
            ExecStart =
              "${config.services.syncthing.tray.package}/bin/${config.services.syncthing.tray.package.pname}";
          };

          Install = { WantedBy = [ "graphical-session.target" ]; };
        };
      };
    })
  ];
}
