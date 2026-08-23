{ config, pkgs, ... }:

{
  imports = [ ../../../../modules/home/common/state-paths.nix ];

  home.packages = [ (pkgs.callPackage ../../package.nix { }) ];

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.omp";
      owner = "Oh My Pi";
      backup = "separate-policy";
      description = "Oh My Pi authentication, configuration, session, history, plugins, hooks, and cache contents remain writable and external and are never linked into the Nix Store.";
    }
  ];
}
