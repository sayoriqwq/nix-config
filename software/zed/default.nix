{ intentLib }:

{
  guiEditor = intentLib.addModules {
    darwinModules = [ ./capabilities/gui-editor/darwin.nix ];
    homeModules = [ ./capabilities/gui-editor/home.nix ];
  };

  fishQuickCommand = intentLib.addModules {
    homeModules = [ ./capabilities/gui-editor/fish.nix ];
  };

  zshQuickCommand = intentLib.addModules {
    homeModules = [ ./capabilities/gui-editor/zsh.nix ];
  };

  addTask =
    { name, command }:
    intentLib.addModules {
      homeModules = [
        {
          sayori.zed.tasks = [
            {
              label = name;
              inherit command;
              shell.program = "sh";
              hide = "on_success";
              reveal_target = "center";
              show_summary = false;
              show_command = false;
              allow_concurrent_runs = true;
              use_new_terminal = true;
            }
          ];
        }
      ];
    };
}
