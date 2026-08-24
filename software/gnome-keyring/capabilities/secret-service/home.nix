{ config, ... }:

{
  # Home attachment contract: package = none; managed configuration = none;
  # mutable-state path = ~/.local/share/keyrings below; services = none in this
  # layer; network effects = none; human gate = login unlock and credential
  # access smoke, with no automatic state migration or cleanup.
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
