{ lib }:

let
  compose = import ../lib.nix { inherit lib; };
  software = {
    fish = import ../../software/fish;
    ghostty = import ../../software/ghostty;
    yumeDesign = import ../../software/yume-design;
  };
in
compose [
  software.fish.interactiveShell
  software.yumeDesign.terminalTheme
  software.ghostty.terminalEmulator
]
