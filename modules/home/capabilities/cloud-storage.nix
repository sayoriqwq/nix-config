{ config, ... }:

{
  imports = [
    ../common/state-paths.nix
    ../common/cli/rclone.nix
  ];

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.config/rclone/rclone.conf";
      owner = "rclone";
      backup = "separate-policy";
      description = "Mutable remote definitions and credentials; never managed by Nix or committed.";
    }
  ];
}
