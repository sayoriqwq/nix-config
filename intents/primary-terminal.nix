{ lib }:

let
  compose = import ./lib.nix { inherit lib; };
  fish = import ../software/fish;
in
compose [
  fish.interactiveShell
  { homeModules = [ ../software/ghostty/home-manager.nix ]; }
]
