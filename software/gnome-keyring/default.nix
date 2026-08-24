{ intentLib }:

{
  secretService = intentLib.addModules {
    nixosModules = [ ./capabilities/secret-service/nixos.nix ];
  };
}
