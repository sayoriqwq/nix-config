{ config, ... }:

{
  imports = [
    ../common/state-paths.nix
    ../common/cli/direnv.nix
    ../common/cli/mise.nix
    ../common/cli/uv.nix
  ];

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.local/share/mise";
      owner = "mise";
      backup = "excluded";
      description = "Downloaded runtimes and mutable tool installations.";
    }
    {
      path = "${config.home.homeDirectory}/.cache/uv";
      owner = "uv";
      backup = "excluded";
      description = "Recreatable Python package and interpreter cache.";
    }
  ];
}
