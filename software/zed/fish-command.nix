{ pkgs, ... }:

let
  editorCommand = import ./command.nix pkgs;
in
{
  # zoxide uses `--cmd cd`, so this quick command remains unambiguous.
  programs.fish.functions.z = ''
    if test (count $argv) -eq 0
        command ${editorCommand} .
    else
        command ${editorCommand} $argv
    end
  '';
}
