{ config, ... }:

{
  imports = [
    ../common/state-paths.nix
    ../darwin/integrations/orbstack.nix
  ];

  programs.man.generateCaches = false;

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.orbstack";
      owner = "OrbStack";
      backup = "separate-policy";
      description = "Container runtime integration, VM, image, container and volume state remain outside Nix ownership.";
    }
  ];
}
