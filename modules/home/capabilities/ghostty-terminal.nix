{ lib, ... }:

let
  keybindings = import ../desktop/terminal/keybindings.nix { inherit lib; };
in
{
  imports = [
    ../desktop/terminal/adapters/ghostty.nix
  ];

  sayori.shortcuts = keybindings.shortcuts;
}
