{ pkgs, ... }:

{
  # Nix owns only the uv executable. Projects remain responsible for their
  # Python version, virtual environment, dependencies, and lock file via uv.
  home.packages = [ pkgs.uv ];
}
