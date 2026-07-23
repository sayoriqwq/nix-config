{ pkgs, ... }:

{
  # GH has no declarative user settings in this repository. Install the CLI
  # without claiming its mutable config.yml or authentication state.
  home.packages = [ pkgs.gh ];
}
