{
  homeManager,
  lib,
  pkgs,
}:

let
  compose = import ../../intents/lib.nix { inherit lib; };
  zed = import ../../software/zed;
  configured = compose [
    zed.guiEditor
    (zed.addTask {
      name = "Test Task";
      command = "test-command";
    })
  ];
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
  merge = lib.replaceStrings [ "/tmp/zed-add-task-check" ] [ "." ] (
    home.config.home.activation.zedSettingsActivation.data
    + home.config.home.activation.zedKeymapActivation.data
    + home.config.home.activation.zedTasksActivation.data
  );
  failures = lib.debug.runTests {
    testMutableTasksEnabled = {
      expr = home.config.programs.zed-editor.mutableUserTasks;
      expected = true;
    };
    testTaskContribution = {
      expr = home.config.programs.zed-editor.userTasks;
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
pkgs.runCommand "zed-add-task-contribution" { nativeBuildInputs = [ pkgs.jq ]; } ''
  mkdir test-home
  cd test-home
  ${merge}
  test -w .config/zed/settings.json
  test ! -L .config/zed/settings.json
  jq -e '.theme.light == "One Light"' .config/zed/settings.json
  cat > .config/zed/settings.json <<'JSON'
  {"theme":{"light":"old","custom":"keep"},"private_extra":true}
  JSON
  cat > .config/zed/keymap.json <<'JSON'
  [{"context":"Workspace","bindings":{"secondary-shift-g":"old","ctrl-x":"keep"}},{"context":"Editor","bindings":{"ctrl-y":"keep"}}]
  JSON
  cat > .config/zed/tasks.json <<'JSON'
  [{"label":"Test Task","command":"old","custom":"keep"},{"label":"Private Task","command":"keep"}]
  JSON
  ${merge}
  jq -e '.theme.light == "One Light" and .theme.custom == "keep" and .private_extra' .config/zed/settings.json
  jq -e 'length == 2 and (map(select(.context == "Workspace"))[0].bindings | .["ctrl-x"] == "keep" and .["secondary-shift-g"][0] == "task::Spawn")' .config/zed/keymap.json
  jq -e 'length == 2 and (map(select(.label == "Test Task"))[0] | .command == "test-command" and .custom == "keep") and any(.[]; .label == "Private Task" and .command == "keep")' .config/zed/tasks.json
  cp -R .config before
  ${merge}
  diff -r before .config
  touch "$out"
''
