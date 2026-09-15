{ config, lib, ... }:

{
  programs.fish.functions.v = ''
    if test (count $argv) -eq 0
        command code .
    else
        command code $argv
    end
  '';

  programs.zsh.initContent = lib.mkIf config.programs.zsh.enable (
    lib.mkOrder 1250 ''
      function v() {
        if (( $# == 0 )); then
          command code .
        else
          command code "$@"
        fi
      }
    ''
  );
}
