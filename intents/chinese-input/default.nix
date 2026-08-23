{ lib }:

let
  intentLib = import ../lib.nix;
  software = {
    fcitx5 = import ../../software/fcitx5 { inherit intentLib; };
    rimeIce = import ../../software/rime-ice { inherit intentLib; };
  };
in
intentLib.realize (
  lib.pipe intentLib.empty [
    software.fcitx5.inputMethod
    software.rimeIce.chineseInputSchema
  ]
)
