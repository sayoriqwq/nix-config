{
  displayManager.nixosModules = [ ./capabilities/display-manager/nixos.nix ];

  disableAutomaticSuspend.nixosModules = [ ./capabilities/disable-automatic-suspend/nixos.nix ];
}
