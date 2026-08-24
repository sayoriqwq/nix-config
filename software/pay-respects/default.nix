{ intentLib }:

{
  commandCorrection = intentLib.addModules {
    homeModules = [ ./capabilities/command-correction/home.nix ];
  };

  zshIntegration = intentLib.addModules {
    homeModules = [ ./capabilities/command-correction/zsh.nix ];
  };
}
