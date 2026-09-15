{
  config,
  lib,
  pkgs,
  ...
}:

let
  editorCommand = import ./command.nix pkgs;
in
lib.mkIf config.programs.zsh.enable {
  programs.zsh.initContent = lib.mkOrder 1251 ''
    function z() {
      if (( $# == 0 )); then
        command ${editorCommand} .
      else
        command ${editorCommand} "$@"
      fi
    }
  '';
}
