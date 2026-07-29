{ lib, ... }:

let
  keybindings = import ../desktop/terminal/keybindings.nix { inherit lib; };
in
{
  imports = [
    ../common/shortcut-reference.nix
    ../desktop/terminal/adapters/ghostty.nix
  ];

  sayori.shortcuts = keybindings.shortcuts;
}
