{ intentLib }:

{
  runtimeManager = intentLib.addModules {
    homeModules = [ ./capabilities/runtime-manager/home.nix ];
  };

  macosRuntimeDefaults = intentLib.addModules {
    homeModules = [ ./capabilities/runtime-manager/macos-defaults.nix ];
  };

  zshIntegration = intentLib.addModules {
    homeModules = [ ./capabilities/runtime-manager/zsh.nix ];
  };
}
