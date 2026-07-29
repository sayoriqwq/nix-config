{
  config,
  lib,
  pkgs,
  ...
}:

let
  forbiddenRuntimePackages = [
    "bun"
    "elixir"
    "erlang"
    "nodejs"
    "nodejs-slim"
  ];
  miseTools = {
    bun = "latest";
    node = "latest";
    pnpm = "latest";
  };
  forbiddenMiseToolNames = [
    "python"
    "uv"
  ];
  profilePackageNames = map lib.getName config.home.packages;
  conflictingRuntimePackages = lib.filter (
    name: builtins.elem name forbiddenRuntimePackages
  ) profilePackageNames;
  conflictingPythonInterpreters = lib.filter (
    name: builtins.match "^python([0-9.]*)$" name != null
  ) profilePackageNames;
  conflictingMiseTools = lib.intersectLists forbiddenMiseToolNames (builtins.attrNames miseTools);
  miseToolLines = lib.concatMapStringsSep "\n" (name: ''${name} = "${miseTools.${name}}"'') (
    builtins.attrNames miseTools
  );
in
{
  assertions = [
    {
      assertion = conflictingRuntimePackages == [ ];
      message = ''
        Node, Bun, Erlang and Elixir runtimes are owned exclusively by mise.
        Remove these packages from Home Manager home.packages:
        ${lib.concatStringsSep ", " conflictingRuntimePackages}
      '';
    }
    {
      assertion = conflictingPythonInterpreters == [ ];
      message = ''
        Python versions are owned by uv at project scope. Remove these Python
        interpreters from Home Manager home.packages:
        ${lib.concatStringsSep ", " conflictingPythonInterpreters}
      '';
    }
    {
      assertion = conflictingMiseTools == [ ];
      message = ''
        Python and uv must not be managed by mise. Remove these tools from the
        shared mise defaults: ${lib.concatStringsSep ", " conflictingMiseTools}
      '';
    }
  ];

  xdg.configFile."mise/conf.d/10-nix-defaults.toml".text = ''
    [tools]
    ${miseToolLines}

    [settings]
    activate_aggressive = true
  '';

  programs.mise = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = lib.mkDefault false;
    package = pkgs.mise;
  };
}
