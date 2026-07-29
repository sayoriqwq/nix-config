{ config, ... }:

{
  imports = [
    ../common/state-paths.nix
    ../desktop/editors/seed-files.nix
    ../desktop/editors/zed
  ];

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.config/zed";
      owner = "Zed";
      backup = "optional";
      description = "Writable live settings, keymap, tasks, extensions and session state; Nix only seeds missing baselines.";
    }
  ];
}
