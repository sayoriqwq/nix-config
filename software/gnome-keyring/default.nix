{ intentLib }:

{
  secretService = intentLib.addModules {
    homeModules = [ ./capabilities/secret-service/home.nix ];
    nixosModules = [ ./capabilities/secret-service/nixos.nix ];
  };
}
