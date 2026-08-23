{ intentLib }:

{
  compatibilityShell = intentLib.addModules {
    homeModules = [ ./capabilities/compatibility-shell/home.nix ];
  };
}
