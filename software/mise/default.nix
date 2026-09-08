{
  runtimeManager.homeModules = [ ./capabilities/runtime-manager/home.nix ];

  macosRuntimeDefaults.homeModules = [ ./capabilities/runtime-manager/macos-defaults.nix ];

  zshIntegration.homeModules = [ ./capabilities/runtime-manager/zsh.nix ];
}
