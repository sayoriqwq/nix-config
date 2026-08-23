{
  lib,
  pkgs,
  username,
  ...
}:

let
  rimeDataPackage = import ./rime-data-package.nix { inherit lib pkgs; };
  rimeAddon = pkgs.fcitx5-rime.override {
    rimeDataPkgs = [ rimeDataPackage ];
  };
in
{
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";

    fcitx5 = {
      addons = [ rimeAddon ];

      # Keep the toolkit modules selected for the first Hyprland trial. The
      # combined package still contains Fcitx's Wayland frontend; this option
      # controls the session integration emitted by the locked NixOS module.
      waylandFrontend = false;

      settings = {
        globalOptions = {
          "Hotkey/TriggerKeys" = { };
          "Hotkey/AltTriggerKeys" = { };
          Behavior = {
            ActiveByDefault = "True";
            ShareInputState = "All";
            AllowInputMethodForPassword = "False";
            resetStateWhenFocusIn = "No";
          };
        };

        inputMethod = {
          GroupOrder."0" = "Default";
          "Groups/0" = {
            Name = "Default";
            "Default Layout" = "us";
            DefaultIM = "rime";
          };
          "Groups/0/Items/0" = {
            Name = "rime";
            Layout = "us";
          };
        };

        # fcitx5-rime's InputState is a global key, not an INI section.
        addons.rime.globalSection.InputState = "All";
      };
    };
  };

  home-manager.users.${username}.imports = [ ./home.nix ];
}
