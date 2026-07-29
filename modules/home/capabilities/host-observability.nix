{ pkgs, ... }:

{
  programs.btop.enable = true;
  home.packages = [ pkgs.fastfetch ];
}
