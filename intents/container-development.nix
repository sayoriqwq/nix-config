{ lib }:

let
  compose = import ./lib.nix { inherit lib; };
  orbstack = import ../software/orbstack;
in
compose [
  orbstack.containerRuntime
  orbstack.shellIntegration
]
