{ pkgs, ... }:

{
  imports = [
    ../../common/state-paths.nix
  ];

  home.packages = [ pkgs.obsidian ];
}
