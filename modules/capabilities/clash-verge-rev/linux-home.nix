{ config, pkgs, ... }:

{
  imports = [ ../../home/common/state-paths.nix ];

  home.packages = [ pkgs.clash-verge-rev ];

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.local/share/io.github.clash-verge-rev.clash-verge-rev";
      owner = "Clash Verge Rev";
      backup = "required";
      description = "Writable profiles, application settings, runtime configuration and logs; no service, TUN or system proxy is enabled by Nix.";
    }
  ];
}
