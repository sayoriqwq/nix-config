{ intentLib }:

{
  shellPrompt = intentLib.addModules {
    homeModules = [ ./capabilities/shell-prompt/home.nix ];
  };

  zshIntegration = intentLib.addModules {
    homeModules = [ ./capabilities/shell-prompt/zsh.nix ];
  };
}
