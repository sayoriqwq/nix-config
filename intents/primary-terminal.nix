{ lib }:

let
  compose = import ./lib.nix { inherit lib; };
  fish = import ../software/fish;
in
compose [
  fish.interactiveShell
  {
    darwinModules = [ { homebrew.casks = [ "ghostty" ]; } ];
    homeModules = [ ../software/ghostty/home-manager.nix ];
  }
]
