{ self, wallpapers, ... }:
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.hsh;
  system = pkgs.stdenv.hostPlatform.system;

  jsonFormat = pkgs.formats.json { };
  inherit (import ./settings-options.nix { inherit lib pkgs; }) settingsSubmodule;

  templateSettings = builtins.fromJSON (builtins.readFile "${self}/config/hsh/settings.json");

  userSettings = lib.filterAttrsRecursive (_: v: v != null) cfg.settings;

  mergedSettings = lib.recursiveUpdate templateSettings userSettings;
  settingsFile = jsonFormat.generate "hsh-settings.json" mergedSettings;

  settingsTarget = "${config.xdg.configHome}/hsh/settings.json";
in
{
  options.programs.hsh = {
    enable = mkEnableOption "the HSH Quickshell desktop shell";

    package = mkOption {
      type = types.package;
      default = self.packages.${system}.default;
      defaultText = literalExpression "hsh.packages.<system>.default";
      description = "The HSH package to use.";
    };

    settings = mkOption {
      type = settingsSubmodule;
      default = { };
      example = literalExpression ''
        {
          bar.position = "left";
          bar.modules.right = [ "tray" [ "kb" "wifi" "bt" "vol" "bat" ] ];
          theme.fontFamily = "Adwaita Mono";
          notifications.dnd = true;
        }
      '';
      description = ''
        HSH configuration, layered on top of the package's
        bundled `config/hsh/settings.json` and written to
        `$XDG_CONFIG_HOME/hsh/settings.json`.
        See settings-options.nix for the full list of typed fields;
        anything not listed there can still be set as a plain
        attribute.
      '';
    };

    systemd = {
      enable = mkOption {
        type = types.bool;
        default = pkgs.stdenv.isLinux;
        description = "Whether to run hshd as a `systemd --user` service.";
      };

      target = mkOption {
        type = types.str;
        default = "graphical-session.target";
        description = "Target hshd is tied to (start/stop/restart with it).";
      };

      environment = mkOption {
        type = types.attrsOf types.str;
        default = { };
        example = { QT_QPA_PLATFORM = "wayland"; };
        description = "Extra environment variables for the hshd unit.";
      };
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    programs.hsh.settings.wallpaperDir = mkDefault "${config.home.homeDirectory}/Pictures/Wallpapers";

    home.activation.hshSettings = hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p ${escapeShellArg (builtins.dirOf settingsTarget)}
      if [ ! -e ${escapeShellArg settingsTarget} ]; then
        run install -m 0644 ${settingsFile} ${escapeShellArg settingsTarget}
      fi
    '';

    home.activation.hshWallpapers = hm.dag.entryAfter [ "writeBoundary" ] ''
      target=${escapeShellArg "${config.home.homeDirectory}/Pictures/Wallpapers"}
      src=${escapeShellArg "${wallpapers}"}
      if [ -d "$src/images" ]; then
        src="$src/images"
      fi
      run mkdir -p "$target"
      run find "$src" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' \) -exec cp -f {} "$target"/ \;
    '';

    systemd.user.services.hsh = mkIf cfg.systemd.enable {
      Unit = {
        Description = "HSH shell daemon";
        After = [ cfg.systemd.target ];
        PartOf = [ cfg.systemd.target ];
        X-Restart-Triggers = [ "${settingsFile}" ];
      };

      Service = {
        ExecStart = "${cfg.package}/bin/hshd start";
        Restart = "on-failure";
        KillMode = "mixed";
        TimeoutStopSec = "5s";
        Environment = mapAttrsToList (n: v: "${n}=${v}") cfg.systemd.environment;
      };

      Install.WantedBy = [ cfg.systemd.target ];
    };
  };
}
