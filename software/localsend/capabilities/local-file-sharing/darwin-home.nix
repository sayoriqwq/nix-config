{ config, ... }:

{
  imports = [ ./home.nix ];

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/Library/Containers/org.localsend.localsendApp";
      owner = "LocalSend";
      backup = "optional";
      description = "Writable main application container; received files remain user data outside this path.";
    }
    {
      path = "${config.home.homeDirectory}/Library/Containers/org.localsend.localsendApp.ShareExtension";
      owner = "LocalSend";
      backup = "optional";
      description = "Writable macOS Share Extension state.";
    }
    {
      path = "${config.home.homeDirectory}/Library/Group Containers/--AppIdentifierPrefix-localsend.shared_group";
      owner = "LocalSend";
      backup = "optional";
      description = "Writable state shared by the LocalSend app and Share Extension.";
    }
    {
      path = "${config.home.homeDirectory}/Library/Preferences/org.localsend.localsendApp.plist";
      owner = "LocalSend";
      backup = "optional";
      description = "Writable macOS preferences observed on macbook.";
    }
  ];
}
