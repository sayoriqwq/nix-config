{ config, ... }:

{
  imports = [ ../../../../modules/home/common/state-paths.nix ];

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.local/share/keyrings";
      owner = "GNOME Keyring";
      backup = "separate-policy";
      description = "Sensitive mutable credentials owned by the retained Secret Service; never place them in Git or the Nix store.";
    }
  ];
}
