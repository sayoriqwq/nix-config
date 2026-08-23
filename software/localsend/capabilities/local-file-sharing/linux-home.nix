{ config, ... }:

{
  imports = [ ./home.nix ];

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.local/share/org.localsend.localsend_app";
      owner = "LocalSend";
      backup = "optional";
      description = "Writable Linux preferences and application support data; received files remain user data at user-selected paths.";
    }
  ];
}
