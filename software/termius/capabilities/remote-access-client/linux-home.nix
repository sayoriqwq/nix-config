{ config, pkgs, ... }:

{
  imports = [ ../../../../modules/home/common/state-paths.nix ];

  home.packages = [ pkgs.termius ];

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.config/Termius";
      owner = "Termius";
      backup = "required";
      description = "Writable Electron user data, authentication and connection state; credentials remain outside Nix and Git.";
    }
  ];
}
