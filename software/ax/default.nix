{ intentLib }:

{
  webInspection = intentLib.addModules {
    homeModules = [ ./capabilities/web-inspection/home.nix ];
  };
}
