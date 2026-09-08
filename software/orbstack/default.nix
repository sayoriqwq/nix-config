{
  containerRuntime.darwinModules = [ ./capabilities/container-runtime/darwin.nix ];

  shellIntegration.homeModules = [ ./capabilities/container-runtime/home.nix ];
}
