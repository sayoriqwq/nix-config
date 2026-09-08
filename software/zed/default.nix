{
  guiEditor = {
    darwinModules = [ ./capabilities/gui-editor/darwin.nix ];
    homeModules = [ ./capabilities/gui-editor/home.nix ];
  };

  fishQuickCommand.homeModules = [ ./capabilities/gui-editor/fish.nix ];

  zshQuickCommand.homeModules = [ ./capabilities/gui-editor/zsh.nix ];

  addTask =
    { name, command }:
    {
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
