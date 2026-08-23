{ intentLib }:

{
  desktopStatus = intentLib.addModules {
    homeModules = [ ./capabilities/desktop-status/home.nix ];
  };
}
