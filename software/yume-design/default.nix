{ intentLib }:

{
  terminalTheme = intentLib.addModules {
    homeModules = [ ./capabilities/terminal-theme/home.nix ];
  };
}
