{ intentLib }:

{
  networkConnectivity = intentLib.addModules {
    nixosModules = [ ./capabilities/network-connectivity/nixos.nix ];
  };
}
