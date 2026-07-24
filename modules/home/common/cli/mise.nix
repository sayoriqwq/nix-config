{
  config,
  lib,
  pkgs,
  ...
}:

let
  forbiddenRuntimePackages = [
    "bun"
    "nodejs"
    "nodejs-slim"
  ];
  profilePackageNames = map lib.getName config.home.packages;
  conflictingRuntimePackages = lib.filter (
    name: builtins.elem name forbiddenRuntimePackages
  ) profilePackageNames;
in
{
  assertions = [
    {
      assertion = conflictingRuntimePackages == [ ];
      message = ''
        Node and Bun are owned exclusively by mise. Remove these packages from
        Home Manager home.packages: ${lib.concatStringsSep ", " conflictingRuntimePackages}
      '';
    }
  ];

  xdg.configFile."mise/conf.d/10-nix-defaults.toml".text = ''
    [tools]
    bun = "latest"
    node = "latest"
    pnpm = "latest"

    [settings]
    activate_aggressive = true
  '';

  programs.mise = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
    package = pkgs.mise;
  };
}
