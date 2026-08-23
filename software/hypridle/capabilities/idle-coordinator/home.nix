{
  # Hypridle remains the lock/sleep coordinator, but the always-on requirement
  # deliberately provides no timers that lock, blank displays or suspend.
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        after_sleep_cmd = "hyprctl dispatch dpms on";
        before_sleep_cmd = "loginctl lock-session";
        lock_cmd = "pidof hyprlock || hyprlock";
      };

      listener = [ ];
    };
  };
}
