{ config, ... }:

{
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
