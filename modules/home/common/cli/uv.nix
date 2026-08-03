{ pkgs, ... }:

{
  # This primitive owns only the uv executable. Projects remain responsible
  # for their Python version, virtual environment, dependencies, and lock file.
  # The agent-only baseline interpreter is declared by a separate primitive.
  home.packages = [ pkgs.uv ];
}
