{ lib }:

capabilities: {
  darwinModules = lib.concatMap (capability: capability.darwinModules or [ ]) capabilities;
  nixosModules = lib.concatMap (capability: capability.nixosModules or [ ]) capabilities;
  homeModules = lib.concatMap (capability: capability.homeModules or [ ]) capabilities;
}
