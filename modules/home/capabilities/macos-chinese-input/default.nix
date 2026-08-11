{
  config,
  lib,
  pkgs,
  ...
}:

let
  rimeDataView = import ./rime-data-view.nix { inherit lib pkgs; };
  homePath = relativePath: "${config.home.homeDirectory}/${relativePath}";
in
{
  imports = [ ../../common/state-paths.nix ];

  # Home Manager recursively links the view's leaves, so the Rime user-data
  # root remains a real writable directory for deployment output and user data.
  xdg.dataFile."fcitx5/rime" = {
    source = rimeDataView;
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
      description = "Fcitx5 owns its writable configuration and preferences; nix-config does not reconcile them.";
    }
    {
      path = homePath "Library/fcitx5";
      owner = "Fcitx5 macOS installer/updater";
      backup = "separate-policy";
      description = "Fcitx5 plugin payload, shared resources, and plugin-manager state remain externally owned.";
    }
    {
      path = homePath "Library/Caches/org.fcitx.inputmethod.Fcitx5";
      owner = "Fcitx5";
      backup = "excluded";
      description = "Rebuildable Fcitx5 macOS cache remains writable and outside the Nix store.";
    }
  ];
}
