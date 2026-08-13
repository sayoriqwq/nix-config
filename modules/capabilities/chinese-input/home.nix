{
  config,
  lib,
  pkgs,
  ...
}:

let
  rimeDataPackage = import ./rime-data-package.nix { inherit lib pkgs; };
  homePath = relativePath: "${config.home.homeDirectory}/${relativePath}";
in
{
  imports = [ ../../home/common/state-paths.nix ];

  # Keep the Rime user-data root writable. Home Manager links only immutable
  # leaves from the shared package into it on both supported frontends.
  xdg.dataFile."fcitx5/rime" = {
    source = "${rimeDataPackage}/share/rime-data";
    recursive = true;
  };

  sayori.statePaths = [
    {
      path = homePath ".local/share/fcitx5/rime/build";
      owner = "Rime";
      backup = "excluded";
      description = "Rebuildable Rime deployment cache remains writable and outside the Nix store.";
    }
    {
      path = homePath ".local/share/fcitx5/rime/luna_pinyin.userdb";
      owner = "Rime";
      backup = "required";
      description = "Rime learning data remains writable; its entries must never be inspected or committed.";
    }
    {
      path = homePath ".local/share/fcitx5/rime/rime_ice.userdb";
      owner = "Rime";
      backup = "required";
      description = "Rime Ice learning data remains writable; its entries must never be inspected or committed.";
    }
    {
      path = homePath ".local/share/fcitx5/rime/sync";
      owner = "Rime";
      backup = "separate-policy";
      description = "Rime sync exports remain writable and follow their own data backup procedure.";
    }
    {
      path = homePath ".local/share/fcitx5/rime/installation.yaml";
      owner = "Rime";
      backup = "required";
      description = "Rime installation identity remains mutable and is not a static declaration.";
    }
    {
      path = homePath ".local/share/fcitx5/rime/user.yaml";
      owner = "Rime";
      backup = "required";
      description = "Rime deployment and recent-schema state remains mutable.";
    }
    {
      path = homePath ".config/fcitx5";
      owner = "Fcitx5";
      backup = "required";
      description = "Fcitx5 owns its writable user configuration and preferences; nix-config never replaces the user root.";
    }
  ];
}
