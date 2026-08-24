{ intentLib }:

{
  inputMethod = intentLib.addModules {
    darwinModules = [ ./capabilities/input-method/darwin.nix ];
    nixosModules = [ ./capabilities/input-method/nixos.nix ];
  };
}
