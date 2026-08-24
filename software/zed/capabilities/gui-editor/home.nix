{
  config,
  lib,
  pkgs,
  ...
}:

let
  configDirectory = "${config.home.homeDirectory}/.config/zed";
  tasksBaseline = pkgs.writeText "zed-tasks.json" (builtins.toJSON config.sayori.zed.tasks);
  zedPackage =
    if pkgs.stdenv.hostPlatform.isDarwin then
      pkgs.callPackage ../../package.nix { }
    else
      pkgs.zed-editor;
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
    # ADR-0006: macOS pins an official Preview binary; Linux follows the stable
    # zed-editor from its release Nixpkgs package set and binary caches.
    home.packages = [ zedPackage ];

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

  };
}
