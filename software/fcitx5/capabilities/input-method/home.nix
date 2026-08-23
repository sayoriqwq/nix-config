{ config, ... }:

{
  imports = [ ../../../../modules/home/common/state-paths.nix ];

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.config/fcitx5";
      owner = "Fcitx5";
      backup = "required";
      description = "Fcitx5 owns its writable user configuration and preferences; nix-config never replaces the user root.";
    }
  ];
}
