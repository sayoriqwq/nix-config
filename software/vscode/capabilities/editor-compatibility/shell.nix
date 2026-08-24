{ lib, ... }:

{
  imports = [
    ../../../../modules/home/common/shortcut-reference.nix
  ];

  programs.fish.functions.v = ''
    if test (count $argv) -eq 0
        command code .
    else
        command code $argv
    end
  '';

  programs.zsh.initContent = lib.mkOrder 1250 ''
    function v() {
      if (( $# == 0 )); then
        command code .
      else
        command code "$@"
      fi
    }
  '';

  sayori.shortcuts = [
    {
      scope = "Fish / Zsh";
      keys = "v";
      action = "无参数打开当前目录；有参数传给 VS Code";
      owner = "vscode";
      order = 45;
    }
  ];
}
