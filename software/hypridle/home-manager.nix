{
  # Capability contract (Home Manager): package = Hypridle from the Home
  # Manager service; managed configuration = lock/sleep hooks with no listeners;
  # mutable-state paths = none; services = hypridle user service; network effects
  # = none.
  # 激活后验证手动锁屏、休眠前锁屏与唤醒亮屏。
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
