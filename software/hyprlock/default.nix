{ intentLib }:

{
  sessionLock = intentLib.addModules {
    homeModules = [ ./capabilities/session-lock/home.nix ];
    nixosModules = [ ./capabilities/session-lock/nixos.nix ];
  };
}
