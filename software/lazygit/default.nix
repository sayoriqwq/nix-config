{ intentLib }:

{
  gitTui = intentLib.addModules {
    homeModules = [ ./capabilities/git-tui/home.nix ];
  };
}
