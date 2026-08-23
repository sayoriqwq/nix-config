{
  lib,
  pkgs,
  username,
  ...
}:

let
  rimeDataPackage = import ./data-package.nix { inherit lib pkgs; };
  rimeAddon = pkgs.fcitx5-rime.override {
    rimeDataPkgs = [ rimeDataPackage ];
  };
in
{
  # Capability contract (NixOS): package = the filtered Rime Ice data package
  # plus fcitx5-rime addon; managed configuration = the sole Rime group/default
  # and InputState; mutable-state paths = Rime build/userdb/sync/identity files
  # via the Home attachment; services = none beyond Fcitx5's frontend; network
  # effects = none; human gate = activation, deploy and real-input smoke.
  i18n.inputMethod.fcitx5 = {
    addons = [ rimeAddon ];
    settings = {
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

      addons.rime.globalSection.InputState = "All";
    };
  };

  home-manager.users.${username}.imports = [ ./home.nix ];
}
