{ lib }:

let
  intentLib = import ../lib.nix;
  software = {
    fish = import ../../software/fish { inherit intentLib; };
    ghostty = import ../../software/ghostty { inherit intentLib; };
    yumeDesign = import ../../software/yume-design { inherit intentLib; };
  };
in
intentLib.realize (
  lib.pipe intentLib.empty [
    software.fish.interactiveShell
    software.yumeDesign.terminalTheme
    software.ghostty.terminalEmulator
  ]
)
