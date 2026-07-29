{ pkgs, ... }:

{
  imports = [
    ../../home/common/state-paths.nix
  ];

  home.packages = [ pkgs.localsend ];
}
