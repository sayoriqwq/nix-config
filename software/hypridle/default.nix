{ intentLib }:

{
  idleCoordinator = intentLib.addModules {
    homeModules = [ ./capabilities/idle-coordinator/home.nix ];
  };
}
