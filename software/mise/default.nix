{
  runtimeManager.homeModules = [ ./home-manager.nix ];

  macosRuntimeDefaults.homeModules = [ ./macos-defaults.nix ];

  zshIntegration.homeModules = [ ./zsh-integration.nix ];
}
