{ lib }:

let
  intentLib = import ../lib.nix;
  software = {
    wezterm = import ../../software/wezterm { inherit intentLib; };
    zsh = import ../../software/zsh { inherit intentLib; };
  };
  zshIntegrations = intentLib.addModules {
    homeModules = [ ./zsh-integrations.nix ];
  };
in
intentLib.realize (
  lib.pipe intentLib.empty [
    software.zsh.compatibilityShell
    software.wezterm.terminalEmulator
    zshIntegrations
  ]
)
