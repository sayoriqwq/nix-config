{
  guiEditor = {
    darwinModules = [ ./darwin.nix ];
    homeModules = [ ./home-manager.nix ];
  };

  fishQuickCommand.homeModules = [ ./fish-command.nix ];

  zshQuickCommand.homeModules = [ ./zsh-command.nix ];

  addTask =
    { name, command }:
    {
      homeModules = [
        {
          programs.zed-editor.userTasks = [
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
