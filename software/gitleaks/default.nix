{ intentLib }:

{
  secretScanner = intentLib.addModules {
    homeModules = [ ./capabilities/secret-scanner/home.nix ];
  };
}
