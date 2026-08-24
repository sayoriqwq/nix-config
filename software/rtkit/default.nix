{ intentLib }:

{
  realtimeScheduling = intentLib.addModules {
    nixosModules = [ ./capabilities/realtime-scheduling/nixos.nix ];
  };
}
