{ lib }:

let
  compose = import ../lib.nix { inherit lib; };
  software = {
    gdm = import ../../software/gdm;
    hypridle = import ../../software/hypridle;
  };
in
compose [
  software.hypridle.idleCoordinator
  software.gdm.displayManager
  software.gdm.disableAutomaticSuspend
]
