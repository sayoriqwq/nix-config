{ config, pkgs, ... }:

{
  imports = [ ../../../../modules/home/common/state-paths.nix ];

  home.packages = [ pkgs.google-chrome ];

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.config/google-chrome";
      owner = "Google Chrome";
      backup = "optional";
      description = "Writable browser profiles, history, cookies and local state; Nix only owns the package.";
    }
    {
      path = "${config.home.homeDirectory}/.cache/google-chrome";
      owner = "Google Chrome";
      backup = "excluded";
      description = "Recreatable Linux browser cache.";
    }
  ];
}
