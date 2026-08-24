{ intentLib }:

{
  inputMethod = intentLib.addModules {
    nixosModules = [ ./capabilities/input-method/nixos.nix ];
  };
}
