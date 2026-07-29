{ pkgs, ... }:

{
  # Authentication, keys, history and sync state remain writable application
  # data. Nix owns only the optional desktop client package.
  home.packages = [ pkgs.atuin-desktop ];
}
