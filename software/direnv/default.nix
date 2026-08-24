{ intentLib }:

{
  developmentEnvironment = intentLib.addModules {
    homeModules = [ ./capabilities/development-environment/home.nix ];
  };

  zshIntegration = intentLib.addModules {
    homeModules = [ ./capabilities/development-environment/zsh.nix ];
  };
}
