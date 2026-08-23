{
  config,
  lib,
  pkgs,
  ...
}:

let
  configDirectory = "${config.home.homeDirectory}/.config/zed";
  tasksBaseline = pkgs.writeText "zed-tasks.json" (builtins.toJSON config.sayori.zed.tasks);
  zedNightly = pkgs.callPackage ../../package.nix { };
in
{
  imports = [
    ../../../../modules/home/common/shortcut-reference.nix
    ../../../../modules/home/common/state-paths.nix
    ../../../../modules/home/desktop/editors/seed-files.nix
  ];

  options.sayori.zed.tasks = lib.mkOption {
    type = lib.types.listOf lib.types.attrs;
    default = [ ];
    internal = true;
    description = "Tasks contributed through Zed's owner-local addTask interface.";
  };

  config = {
    # ADR-0006: both workstations use the same exact official Nightly release.
    # The package adapts upstream prebuilt artifacts and has no Rust build path.
    home.packages = [
      zedNightly
      pkgs.nil
      pkgs.nixd
    ];

    # Zed is the sole owner of the default editor role. VS Code and Helix remain
    # available as explicit fallback editors.
    home.sessionVariables = {
      EDITOR = "zed --wait";
      VISUAL = "zed --wait";
    };

    # Live files stay writable. The generated task baseline is used only when
    # the target is completely missing, like the two static editor baselines.
    sayori.editors.seedFiles = [
      {
        target = "${configDirectory}/settings.json";
        baseline = ./settings.jsonc;
      }
      {
        target = "${configDirectory}/keymap.json";
        baseline = ./keymap.jsonc;
      }
      {
        target = "${configDirectory}/tasks.json";
        baseline = tasksBaseline;
      }
    ];

    sayori.statePaths = [
      {
        path = configDirectory;
        owner = "Zed";
        backup = "optional";
        description = "Writable live settings, keymap, tasks, extensions and session state; Nix only seeds missing baselines.";
      }
    ];

    # `z` is part of the Zed capability. zoxide uses `--cmd cd`, so the name is
    # unambiguous on both workstations.
    programs.fish.functions.z = ''
      if test (count $argv) -eq 0
          command zed .
      else
          command zed $argv
      end
    '';

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
  };
}
