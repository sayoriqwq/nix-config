{ intentLib }:

{
  displayManager = intentLib.addModules {
    nixosModules = [ ./capabilities/display-manager/nixos.nix ];
  };

  disableAutomaticSuspend = intentLib.addModules {
    nixosModules = [ ./capabilities/disable-automatic-suspend/nixos.nix ];
  };
}
