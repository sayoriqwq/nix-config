{ lib, ... }:

{
  # These launchers are intentionally macbook-only. The editor capabilities
  # provide `code` and `zed`; this capability owns only the short shell names.
  programs.fish.functions = {
    v = ''
      if test (count $argv) -eq 0
          command code .
      else
          command code $argv
      end
    '';

    z = ''
      if test (count $argv) -eq 0
          command zed .
      else
          command zed $argv
      end
    '';
  };

  # Keep these after zoxide's initialization and before the compatibility
  # shell's key bindings. zoxide uses `cd`, so `z` remains available for Zed.
  programs.zsh.initContent = lib.mkOrder 1250 ''
    function v() {
      if (( $# == 0 )); then
        command code .
      else
        command code "$@"
      fi
    }

    function z() {
      if (( $# == 0 )); then
        command zed .
      else
        command zed "$@"
      fi
    }
  '';

  sayori.shortcuts = [
    {
      scope = "Fish / Zsh";
      keys = "v";
      action = "无参数打开当前目录；有参数传给 VS Code";
      owner = "macos-editor-launchers";
      order = 45;
    }
    {
      scope = "Fish / Zsh";
      keys = "z";
      action = "无参数打开当前目录；有参数传给 Zed";
      owner = "macos-editor-launchers";
      order = 46;
    }
  ];
}
