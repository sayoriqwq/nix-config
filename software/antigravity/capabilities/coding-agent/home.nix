{ config, pkgs, ... }:

{
  imports = [ ../../../../modules/home/common/state-paths.nix ];

  home.packages = [ (pkgs.callPackage ../../package.nix { }) ];

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.gemini";
      owner = "Antigravity CLI";
      backup = "separate-policy";
      description = "Antigravity CLI authentication, configuration, session, history, plugins, hooks, and cache contents remain writable and external and are never linked into the Nix Store.";
    }
  ];
}
