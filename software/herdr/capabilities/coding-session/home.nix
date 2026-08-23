{ inputs, pkgs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  # Runtime sessions, workspaces and plugins remain outside Home Manager.
  home.packages = [ inputs.herdr.packages.${system}.default ];
}
