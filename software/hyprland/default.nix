{ intentLib }:

{
  graphicalSession = intentLib.addModules {
    homeModules = [ ./capabilities/graphical-session/home.nix ];
    nixosModules = [ ./capabilities/graphical-session/nixos.nix ];
  };
}
