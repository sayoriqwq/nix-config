{ intentLib }:

{
  applicationLauncher = intentLib.addModules {
    homeModules = [ ./capabilities/application-launcher/home.nix ];
  };
}
