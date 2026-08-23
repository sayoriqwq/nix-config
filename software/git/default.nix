{ intentLib }:

{
  versionControl = intentLib.addModules {
    homeModules = [ ./capabilities/version-control/home.nix ];
  };
}
