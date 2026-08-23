{
  inputs,
  nixosAnywherePackage,
  pkgs,
  self,
  serverModules,
  username,
}:

let
  installConfiguration = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = {
      inherit inputs self username;
    };
    modules = serverModules ++ [ ./install-module.nix ];
  };
in
{
  inherit installConfiguration;
  networkTest = import ./network-test.nix {
    inherit
      inputs
      pkgs
      self
      serverModules
      username
      ;
  };
  runner = import ./runner.nix {
    inherit nixosAnywherePackage pkgs;
  };
}
