# empty-dock/default.nix
# NixOS / home-manager module for the Hyprland empty-workspace dock.
#
# Usage in home.nix:
#   imports = [ /path/to/empty-dock/default.nix ];
#   services.emptyDock.enable = true;

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.emptyDock;

  # Package the scripts as a derivation so they land in the Nix store
  # and are referenced by absolute paths in the systemd unit.
  dockPackage = pkgs.stdenv.mkDerivation {
    pname = "empty-dock";
    version = "0.1.0";
    src = ./.;
    nativeBuildInputs = [ pkgs.makeWrapper ];
    installPhase = ''
      mkdir -p $out/share/empty-dock/lib
      mkdir -p $out/share/empty-dock/tests/mocks/fixtures

      cp apps.json config.jsonc style.css $out/share/empty-dock/ 2>/dev/null || true

      for script in waybar-monitor.sh update-launchers.sh launch-app.sh \
                    context-menu.sh add-app.sh; do
        cp "$script" "$out/share/empty-dock/$script"
        chmod +x "$out/share/empty-dock/$script"
      done

      cp lib/log.sh $out/share/empty-dock/lib/log.sh
    '';
  };

in {
  options.services.emptyDock = {
    enable = mkEnableOption "Hyprland empty-workspace dock";

    pollInterval = mkOption {
      type    = types.int;
      default = 2;
      description = "Seconds between workspace emptiness checks.";
    };

    logFile = mkOption {
      type    = types.str;
      default = "%h/.local/share/empty-dock/empty-dock.log";
      description = "Path for the daemon log file (systemd specifiers allowed).";
    };

    dockDir = mkOption {
      type    = types.str;
      default = "${dockPackage}/share/empty-dock";
      description = "Directory containing the dock scripts and config.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      waybar
      jq
      rofi-wayland
      socat
      # hyprland is assumed to be the compositor providing hyprctl
    ];

    # Systemd user service that runs the workspace-monitor daemon.
    systemd.user.services.empty-dock = {
      Unit = {
        Description     = "Hyprland empty-workspace dock monitor";
        After           = [ "graphical-session.target" ];
        PartOf          = [ "graphical-session.target" ];
        Documentation   = "file://${cfg.dockDir}/README.md";
      };

      Service = {
        Type        = "simple";
        ExecStart   = "${cfg.dockDir}/waybar-monitor.sh";
        Restart     = "on-failure";
        RestartSec  = 3;
        Environment = [
          "EMPTY_DOCK_POLL=${toString cfg.pollInterval}"
          "EMPTY_DOCK_LOG=${cfg.logFile}"
          "PATH=${lib.makeBinPath (with pkgs; [ hyprland jq waybar coreutils ])}"
        ];
      };

      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
