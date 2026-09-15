{
  displayManager.nixosModules = [ ./display-manager-nixos.nix ];

  disableAutomaticSuspend.nixosModules = [ ./disable-automatic-suspend-nixos.nix ];
}
