{ intentLib }:

{
  containerRuntime = intentLib.addModules {
    darwinModules = [ ./capabilities/container-runtime/darwin.nix ];
  };

  shellIntegration = intentLib.addModules {
    homeModules = [ ./capabilities/container-runtime/home.nix ];
  };
}
