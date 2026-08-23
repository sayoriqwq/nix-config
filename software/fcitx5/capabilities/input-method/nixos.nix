{ username, ... }:

{
  # Fcitx5 owns the Linux frontend package, session environment and service.
  # User preferences remain writable; activation and real input tests are
  # deferred to the machine-local release gate.
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

  home-manager.users.${username}.imports = [ ./home.nix ];
}
