{ intentLib }:

{
  shellHistory = intentLib.addModules {
    homeModules = [ ./capabilities/shell-history/home.nix ];
  };

  zshIntegration = intentLib.addModules {
    homeModules = [ ./capabilities/shell-history/zsh.nix ];
  };
}
