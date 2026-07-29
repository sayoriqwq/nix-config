{ config, ... }:

{
  imports = [ ./home.nix ];

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.config/obsidian";
      owner = "Obsidian";
      backup = "optional";
      description = "Writable Linux application, plugin and sync state; vault locations remain user data selected outside Nix.";
    }
  ];
}
