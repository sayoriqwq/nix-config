{ pkgs, ... }:

{
  imports = [ ../../../../modules/home/common/state-paths.nix ];

  home.packages = [ pkgs.localsend ];
}
