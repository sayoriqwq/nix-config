{ intentLib }:

{
  gitTui = intentLib.addModules {
    homeModules = [ ./capabilities/git-tui/home.nix ];
  };

  zshIntegration = intentLib.addModules {
    homeModules = [ ./capabilities/git-tui/zsh.nix ];
  };
}
