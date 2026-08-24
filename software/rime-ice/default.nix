{ intentLib }:

{
  chineseInputSchema = intentLib.addModules {
    darwinModules = [ ./capabilities/chinese-input-schema/darwin.nix ];
    nixosModules = [ ./capabilities/chinese-input-schema/nixos.nix ];
  };
}
