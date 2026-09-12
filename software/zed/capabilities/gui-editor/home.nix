{
  config,
  lib,
  pkgs,
  ...
}:

let
  configDirectory = "${config.home.homeDirectory}/.config/zed";
  tasksBaseline = pkgs.writeText "zed-tasks.json" (builtins.toJSON config.sayori.zed.tasks);
  settingsBaseline =
    if pkgs.stdenv.hostPlatform.isDarwin then
      pkgs.writeText "zed-settings.json" (
        builtins.replaceStrings [ ''"auto_update": false'' ] [ ''"auto_update": true'' ] (
          builtins.readFile ./settings.jsonc
        )
      )
    else
      ./settings.jsonc;
  editorCommand = if pkgs.stdenv.hostPlatform.isDarwin then "zed" else "zeditor";
in
{
  imports = [
    ../../../../modules/home/desktop/editors/seed-files.nix
  ];

  options.sayori.zed.tasks = lib.mkOption {
    type = lib.types.listOf lib.types.attrs;
    default = [ ];
    internal = true;
    description = "Tasks contributed through Zed's owner-local addTask interface.";
  };

  config = {
    # macOS uses a writable native installation; the pinned package remains an
    # explicit recovery output. Linux keeps its release package and update policy.
    home.packages = lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.zed-editor ];

    # Zed is the sole owner of the default editor role. VS Code and Helix remain
    # available as explicit fallback editors.
    home.sessionVariables = {
      EDITOR = "${editorCommand} --wait";
      VISUAL = "${editorCommand} --wait";
    };

    # Live files stay writable. The generated task baseline is used only when
    # the target is completely missing, like the two static editor baselines.
    sayori.editors.seedFiles = [
      {
        target = "${configDirectory}/settings.json";
        baseline = settingsBaseline;
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

  };
}
