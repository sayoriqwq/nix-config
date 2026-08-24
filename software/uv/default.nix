{ intentLib }:

{
  pythonPackageManager = intentLib.addModules {
    homeModules = [ ./capabilities/python-package-manager/home.nix ];
  };
}
