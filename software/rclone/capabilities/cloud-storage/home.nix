{ config, pkgs, ... }:

{
  imports = [ ../../../../modules/home/common/state-paths.nix ];

  home.packages = [ pkgs.rclone ];

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.config/rclone/rclone.conf";
      owner = "rclone";
      backup = "separate-policy";
      description = "Mutable remote definitions and credentials; never managed by Nix or committed.";
    }
  ];
}
