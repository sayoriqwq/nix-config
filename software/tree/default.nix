{ intentLib }:

{
  directoryTree = intentLib.addModules {
    homeModules = [ ./capabilities/directory-tree/home.nix ];
  };
}
