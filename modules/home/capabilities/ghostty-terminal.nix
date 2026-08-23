{ lib, pkgs, ... }:

let
  keybindings = import ../desktop/terminal/keybindings.nix { inherit lib; };
in
{
  imports = [
    ../../../software/yume-design/capabilities/terminal-theme/home.nix
    ../common/shortcut-reference.nix
    ../desktop/terminal/adapters/ghostty.nix
  ];

  home.packages = lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    pkgs.maple-mono.NF-CN
  ];

  sayori.shortcuts = keybindings.shortcuts;
}
