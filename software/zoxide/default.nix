{ intentLib }:

{
  directoryJumper = intentLib.addModules {
    homeModules = [ ./capabilities/directory-jumper/home.nix ];
  };

  zshIntegration = intentLib.addModules {
    homeModules = [ ./capabilities/directory-jumper/zsh.nix ];
  };
}
