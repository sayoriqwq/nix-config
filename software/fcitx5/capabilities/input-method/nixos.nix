{ username, ... }:

{
  # Capability contract (NixOS): package = Fcitx5 from i18n.inputMethod;
  # managed configuration = framework defaults and session environment;
  # mutable-state path = ~/.config/fcitx5 via the Home attachment; services =
  # the package XDG-autostart frontend; network effects = none; human gate =
  # activation, single-daemon verification and real input tests.
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
