{
  # Capability contract (Home Manager): package = Waybar from the Home Manager
  # module; managed configuration = modules and layout below; mutable-state
  # paths = none; services = Waybar user systemd service; network effects = none
  # (the network widget only reads status); human gate = local bar/widget smoke.
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    settings.mainBar = {
      layer = "top";
      position = "top";
      modules-left = [ "hyprland/workspaces" ];
      modules-center = [ "hyprland/window" ];
      modules-right = [
        "pulseaudio"
        "network"
        "clock"
      ];

      "hyprland/window".max-length = 80;
      clock.format = "{:%Y-%m-%d %H:%M}";
    };
  };
}
