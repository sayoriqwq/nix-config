{ lib }:

let
  compose = import ./lib.nix { inherit lib; };
  software = {
    fish = import ../software/fish;
    ghostty = import ../software/ghostty;
  };
in
compose [
  software.fish.interactiveShell
  software.ghostty.terminalEmulator
]
