{ config, ... }:

{
  imports = [
    ../common/state-paths.nix
    ../darwin/integrations/orbstack.nix
    ../darwin/integrations/postgresql.nix
  ];

  programs.man.generateCaches = false;

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.orbstack";
      owner = "OrbStack";
      backup = "separate-policy";
      description = "Container runtime integration, VM, image, container and volume state remain outside Nix ownership.";
    }
    {
      path = "/opt/homebrew/var/postgresql@16";
      owner = "Homebrew PostgreSQL 16";
      backup = "required";
      description = "Existing database data directory; migration remains a separately gated stateful issue.";
    }
  ];
}
