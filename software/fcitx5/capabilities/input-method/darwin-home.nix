{ config, ... }:

let
  homePath = relativePath: "${config.home.homeDirectory}/${relativePath}";
in
{
  # Darwin Home attachment contract: package = none; managed configuration =
  # none; mutable-state paths = ~/Library/fcitx5 plus the Fcitx5 cache below;
  # services = none (the external app owns its process); network effects = none;
  # human gate = installer/update, input-source registration and smoke are manual.
  imports = [ ./home.nix ];

  sayori.statePaths = [
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
