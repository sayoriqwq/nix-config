{ config, ... }:

{
  imports = [
    ../common/state-paths.nix
    ../desktop/editors/seed-files.nix
    ../desktop/editors/vscode
    ../darwin/editors/vscode.nix
  ];

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/Library/Application Support/Code/User/settings.json";
      owner = "VS Code";
      backup = "optional";
      description = "Writable live settings; Nix only seeds a missing baseline.";
    }
  ];
}
