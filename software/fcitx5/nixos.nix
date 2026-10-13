{
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";

    fcitx5 = {
      waylandFrontend = false;
      settings.globalOptions = {
        "Hotkey/TriggerKeys" = { };
        "Hotkey/AltTriggerKeys" = { };
        Behavior = {
          ActiveByDefault = "True";
          ShareInputState = "All";
          AllowInputMethodForPassword = "False";
          resetStateWhenFocusIn = "No";
        };
      };
    };
  };
}
