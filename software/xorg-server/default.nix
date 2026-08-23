{ intentLib }:

{
  compatibilityServer = intentLib.addModules {
    nixosModules = [ ./capabilities/compatibility-server/nixos.nix ];
  };
}
