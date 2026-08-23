{ lib }:

let
  intentLib = import ../lib.nix;
  software = {
    gdm = import ../../software/gdm { inherit intentLib; };
    hypridle = import ../../software/hypridle { inherit intentLib; };
  };
in
intentLib.realize (
  lib.pipe intentLib.empty [
    software.hypridle.idleCoordinator
    software.gdm.disableAutomaticSuspend
  ]
)
