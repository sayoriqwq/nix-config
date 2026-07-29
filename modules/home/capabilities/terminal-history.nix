{ config, ... }:

{
  imports = [
    ../common/shortcut-reference.nix
    ../common/state-paths.nix
    ../common/cli/atuin.nix
  ];

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.local/share/atuin";
      owner = "Atuin";
      backup = "required";
      description = "Local history database, encryption key and daemon state.";
    }
  ];
}
