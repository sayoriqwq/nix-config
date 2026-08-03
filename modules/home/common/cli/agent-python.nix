{ pkgs, ... }:

{
  # Agents need an interpreter that is available without entering a project
  # environment. Project Python versions and dependencies remain uv-owned.
  home.packages = [ pkgs.python314 ];
}
