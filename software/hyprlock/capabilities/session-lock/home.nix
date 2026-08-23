{
  # Capability contract (Home Manager): package = Hyprlock from the Home Manager
  # module; managed configuration = lock UI settings; mutable-state paths = none;
  # services = none (started on demand); network effects = none; human gate =
  # local lock/unlock and password-safety smoke after activation.
  programs.hyprlock = {
    enable = true;
    settings = {
      general.hide_cursor = true;

      input-field = [
        {
          monitor = "";
          size = "320, 60";
          position = "0, 0";
          dots_center = true;
          fade_on_empty = false;
          placeholder_text = "<i>Enter password</i>";
        }
      ];
    };
  };
}
