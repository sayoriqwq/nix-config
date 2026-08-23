{ pkgs, ... }:

{
  # Project Python versions and dependencies remain uv-owned.
  home.packages = [ pkgs.python314 ];
}
