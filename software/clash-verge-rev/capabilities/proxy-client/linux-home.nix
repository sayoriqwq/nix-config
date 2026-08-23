{ config, ... }:

{
  imports = [ ../../../../modules/home/common/state-paths.nix ];

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.local/share/io.github.clash-verge-rev.clash-verge-rev";
      owner = "Clash Verge Rev";
      backup = "required";
      description = "Writable profiles, application settings, runtime configuration and logs; NixOS owns the package and Service Mode, while application TUN and system proxy changes remain activation-gated mutable state.";
    }
  ];
}
