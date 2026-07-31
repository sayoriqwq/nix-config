{ inputs, pkgs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  # Herdr is installed from its pinned upstream release Flake. Its runtime
  # session state, workspaces, and plugins remain outside Home Manager.
  home.packages = [ inputs.herdr.packages.${system}.default ];
}
