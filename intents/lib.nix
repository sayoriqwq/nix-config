{ lib }:

parts: {
  darwinModules = lib.concatMap (part: part.darwinModules or [ ]) parts;
  nixosModules = lib.concatMap (part: part.nixosModules or [ ]) parts;
  homeModules = lib.concatMap (part: part.homeModules or [ ]) parts;
}
