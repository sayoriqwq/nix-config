{ pkgs, ... }:

{
  # RTK.md stays owned by `rtk init -g --codex`; activation never runs init.
  home.packages = [ pkgs.rtk ];
}
