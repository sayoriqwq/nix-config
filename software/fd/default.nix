{ intentLib }:

{
  fileFinder = intentLib.addModules {
    homeModules = [ ./capabilities/file-finder/home.nix ];
  };
}
