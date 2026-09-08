{ lib }:

let
  compose = import ../lib.nix { inherit lib; };
  software = {
    fcitx5 = import ../../software/fcitx5;
    rimeIce = import ../../software/rime-ice;
  };
in
compose [
  software.fcitx5.inputMethod
  software.rimeIce.chineseInputSchema
]
