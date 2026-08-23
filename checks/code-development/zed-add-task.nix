{
  homeManager,
  intentLib,
  lib,
  pkgs,
}:

let
  zed = import ../../software/zed {
    inherit intentLib;
  };
  configured = intentLib.realize (
    lib.pipe intentLib.empty [
      zed.guiEditor
      (zed.addTask {
        name = "Test Task";
        command = "test-command";
      })
    ]
  );
  home = homeManager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = configured.homeModules ++ [
      {
        home = {
          username = "zed-add-task-check";
          homeDirectory = "/tmp/zed-add-task-check";
          stateVersion = "26.05";
        };
      }
    ];
  };
  taskSeed = lib.findFirst (
    seed: seed.target == "/tmp/zed-add-task-check/.config/zed/tasks.json"
  ) null home.config.sayori.editors.seedFiles;
  failures = lib.debug.runTests {
    testTaskSeedExists = {
      expr = taskSeed != null;
      expected = true;
    };
    testTaskContribution = {
      expr = if taskSeed == null then null else builtins.fromJSON (builtins.readFile taskSeed.baseline);
      expected = [
        {
          label = "Test Task";
          command = "test-command";
          shell.program = "sh";
          hide = "on_success";
          reveal_target = "center";
          show_summary = false;
          show_command = false;
          allow_concurrent_runs = true;
          use_new_terminal = true;
        }
      ];
    };
  };
in
assert
  lib.debug.throwTestFailures {
    inherit failures;
    description = "zed.addTask contribution tests";
  } == null;
pkgs.runCommand "zed-add-task-contribution" { } ''
  touch "$out"
''
