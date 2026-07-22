{ lib, ... }:

let
  launchers = {
    v = "code";
    z = "zed";
  };
in
{
  programs.fish.functions = lib.mapAttrs (_: command: {
    description = "Open files or the current directory with ${command}";
    body = ''
      if test (count $argv) -eq 0
          command ${command} .
      else
          command ${command} $argv
      end
    '';
  }) launchers;

  programs.zsh.siteFunctions = lib.mapAttrs (_: command: ''
    if (( $# == 0 )); then
      command ${command} .
    else
      command ${command} "$@"
    fi
  '') launchers;
}
