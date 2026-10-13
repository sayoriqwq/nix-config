{
  lib,
  pkgs,
  ...
}:

let
  rimeDataPackage = import ./data-package.nix { inherit lib pkgs; };
  rimeAddon = pkgs.fcitx5-rime.override {
    rimeDataPkgs = [ rimeDataPackage ];
  };
in
{
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
}
