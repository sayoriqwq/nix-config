{ config, lib, ... }:

{
  imports = [
    ../common/state-paths.nix
    ../desktop/editors/seed-files.nix
    ../desktop/editors/zed
  ];

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.config/zed";
      owner = "Zed";
      backup = "optional";
      description = "Writable live settings, keymap, tasks, extensions and session state; Nix only seeds missing baselines.";
    }
  ];

  # `z` is part of the Zed capability. This keeps the launcher available on
  # both macbook and nixbox while leaving it out of hosts without Zed.
  programs.fish.functions.z = ''
    if test (count $argv) -eq 0
        command zed .
    else
        command zed $argv
    end
  '';

  # zoxide does not own the `z` name here: its integration is configured with
  # `--cmd cd`, so this Zed launcher remains unambiguous.
  programs.zsh.initContent = lib.mkIf config.programs.zsh.enable (
    lib.mkOrder 1251 ''
      function z() {
        if (( $# == 0 )); then
          command zed .
        else
          command zed "$@"
        fi
      }
    ''
  );

  sayori.shortcuts = [
    {
      scope = "Fish / Zsh";
      keys = "z";
      action = "无参数打开当前目录；有参数传给 Zed";
      owner = "zed-editor";
      order = 46;
    }
  ];
}
