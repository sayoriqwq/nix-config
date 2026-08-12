{ ... }:

{
  # This capability owns the absence of idle actions. Hyprland still keeps a
  # lock/sleep coordinator, but no timer may lock, power off displays or
  # suspend the workstation automatically.
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
