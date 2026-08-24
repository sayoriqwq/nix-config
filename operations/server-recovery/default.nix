{
  inputs,
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
}
