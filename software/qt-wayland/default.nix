{ intentLib }:

{
  platformPlugins = intentLib.addModules {
    nixosModules = [ ./capabilities/platform-plugins/nixos.nix ];
  };
}
