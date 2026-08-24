{
  config,
  lib,
  pkgs,
  ...
}:

let
  baseline = ./settings.jsonc;
  target = "${config.home.homeDirectory}/Library/Application Support/Code/User/settings.json";
in
{
  imports = [
    ../../../../modules/home/desktop/editors/seed-files.nix
  ];

  home.packages = [ pkgs.vscode ];

  # VS Code and its extensions keep this file writable. Nix provides only a
  # first-run baseline and never overwrites an existing file or symlink.
  sayori.editors.seedFiles = [ { inherit target baseline; } ];

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
