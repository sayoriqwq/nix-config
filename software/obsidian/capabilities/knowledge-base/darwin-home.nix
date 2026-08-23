{ config, ... }:

{
  imports = [ ./home.nix ];

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/Library/Application Support/obsidian";
      owner = "Obsidian";
      backup = "optional";
      description = "Writable application, plugin and sync state; vault locations remain user data selected outside Nix.";
    }
  ];
}
