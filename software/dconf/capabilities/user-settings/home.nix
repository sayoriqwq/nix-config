{ config, ... }:

{
  # Capability contract (Home Manager): package = none; managed configuration
  # = none; mutable-state path = ~/.config/dconf/user, recorded below but never
  # linked or modified; services = none; network effects = none; human gate =
  # any future preference migration or cleanup requires separate approval.
  imports = [ ../../../../modules/home/common/state-paths.nix ];

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.config/dconf/user";
      owner = "dconf clients";
      backup = "optional";
      description = "Mutable desktop preferences remain user-owned; system generation rollback does not restore this database.";
    }
  ];
}
