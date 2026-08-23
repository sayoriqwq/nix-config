{
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
