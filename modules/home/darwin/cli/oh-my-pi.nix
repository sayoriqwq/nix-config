{ pkgs, ... }:

{
  # OMP uses the upstream standalone Darwin binary and does not depend on the
  # Node or Bun version selected by mise.
  home.packages = [ (pkgs.callPackage ../../../../packages/oh-my-pi { }) ];
}
