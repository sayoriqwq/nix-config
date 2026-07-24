{ pkgs, ... }:

{
  # The official Microsoft build is shared by both desktop roles. Platform
  # adapters own only the live settings path and first-run initialization.
  home.packages = [ pkgs.vscode ];
}
