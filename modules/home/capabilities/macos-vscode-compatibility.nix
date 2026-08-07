{ config, lib, ... }:

{
  imports = [
    ../common/state-paths.nix
    ../desktop/editors/seed-files.nix
    ../desktop/editors/vscode
    ../darwin/editors/vscode.nix
  ];

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/Library/Application Support/Code/User/settings.json";
      owner = "VS Code";
      backup = "optional";
      description = "Writable live settings; Nix only seeds a missing baseline.";
    }
  ];

  # `v` is part of the VS Code capability. Hosts that do not select this
  # capability do not receive the launcher or the VS Code package.
  programs.fish.functions.v = ''
    if test (count $argv) -eq 0
        command code .
    else
        command code $argv
    end
  '';

  # macbook's compatibility Zsh is enabled by the terminal capability. Keep
  # the launcher here so its ownership follows VS Code rather than the shell.
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
      owner = "macos-vscode-compatibility";
      order = 45;
    }
  ];
}
