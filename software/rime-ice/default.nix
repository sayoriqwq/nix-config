{ intentLib }:

{
  chineseInputSchema = intentLib.addModules {
    homeModules = [ ./capabilities/chinese-input-schema/home.nix ];
    nixosModules = [ ./capabilities/chinese-input-schema/nixos.nix ];
  };
}
