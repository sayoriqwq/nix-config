{
  config,
  inputs,
  pkgs,
  ...
}:

let
  system = pkgs.stdenv.hostPlatform.system;
  configDirectory = "${config.home.homeDirectory}/.config/zed";
  baselineDirectory = ./.;
in
{
  # ADR-0006: this is Zed's official Nightly package, pinned by the root
  # flake.lock. The upstream Flake remains a leaf package provider.
  home.packages = [
    inputs.zed.packages.${system}.default
    # The Nix extension exposes both servers; keep both available so its
    # default selection does not depend on an undeclared executable.
    pkgs.nil
    pkgs.nixd
  ];

  # Zed is the sole owner of the default editor role. VS Code and Helix remain
  # available as explicit fallback editors.
  home.sessionVariables = {
    EDITOR = "zed --wait";
    VISUAL = "zed --wait";
  };

  # Zed uses this config directory on both Darwin and Linux. Live files stay
  # writable; these baselines only initialize a completely missing target.
  sayori.editors.seedFiles = [
    {
      target = "${configDirectory}/settings.json";
      baseline = baselineDirectory + "/settings.jsonc";
    }
    {
      target = "${configDirectory}/keymap.json";
      baseline = baselineDirectory + "/keymap.jsonc";
    }
    {
      target = "${configDirectory}/tasks.json";
      baseline = baselineDirectory + "/tasks.jsonc";
    }
  ];
}
