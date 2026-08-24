{ lib }:

let
  intentLib = import ../lib.nix;
  software = {
    ghostty = import ../../software/ghostty { inherit intentLib; };
    yumeDesign = import ../../software/yume-design { inherit intentLib; };
  };
in
intentLib.realize (
  lib.pipe intentLib.empty [
    software.yumeDesign.terminalTheme
    software.ghostty.terminalEmulator
  ]
)
