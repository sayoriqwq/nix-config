{
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
