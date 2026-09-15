{ lib, ... }:

{
  programs.zsh.initContent = lib.mkOrder 1251 ''
    function z() {
      if (( $# == 0 )); then
        command zed .
      else
        command zed "$@"
      fi
    }
  '';
}
