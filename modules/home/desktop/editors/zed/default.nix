{
  config,
  pkgs,
  ...
}:

let
  configDirectory = "${config.home.homeDirectory}/.config/zed";
  baselineDirectory = ./.;
  zedNightly = pkgs.callPackage ../../../../../packages/zed-nightly { };
in
{
  # ADR-0006: both workstations use the same exact official Nightly release.
  # The package adapts upstream prebuilt artifacts and has no Rust build path.
  home.packages = [
    zedNightly
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
