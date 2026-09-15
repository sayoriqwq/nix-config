{ lib }:

let
  compose = import ./lib.nix { inherit lib; };
  wezterm = import ../software/wezterm;
  zsh = import ../software/zsh;
in
compose [
  zsh.compatibilityShell
  wezterm.terminalEmulator
]
