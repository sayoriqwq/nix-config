{ config, pkgs, ... }:

{
  imports = [ ../../../../modules/home/common/state-paths.nix ];

  home.packages = [ pkgs.delta ];

  programs.git = {
    enable = true;
    includes = [ { path = "~/.config/git/identity.inc"; } ];
  };

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.config/git/identity.inc";
      owner = "User";
      backup = "separate-policy";
      description = "Private Git identity included by the managed Git configuration.";
    }
  ];
}
