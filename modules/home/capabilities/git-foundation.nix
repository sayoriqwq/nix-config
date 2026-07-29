{ config, pkgs, ... }:

{
  imports = [
    ../common/state-paths.nix
    ../common/cli/git.nix
  ];

  home.packages = [ pkgs.delta ];

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.config/git/identity.inc";
      owner = "User";
      backup = "separate-policy";
      description = "Private Git identity included by the managed Git configuration.";
    }
  ];
}
