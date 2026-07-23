{ lib, ... }:

let
  keybindings = import ./keybindings.nix { inherit lib; };
in
{
  imports = [
    ./adapters/ghostty.nix
    ./adapters/wezterm.nix
  ];

  sayori.shortcuts = keybindings.shortcuts;
}
