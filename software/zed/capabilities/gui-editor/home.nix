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
    home.packages = [ zedNightly ];

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

  };
}
