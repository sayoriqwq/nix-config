{
  config,
  pkgs,
  ...
}:

let
  baseline = ./settings.jsonc;
  target = "${config.home.homeDirectory}/Library/Application Support/Code/User/settings.json";
in
{
  imports = [
    ../../../../modules/home/desktop/editors/seed-files.nix
  ];

  home.packages = [ pkgs.vscode ];

  # VS Code and its extensions keep this file writable. Nix provides only a
  # first-run baseline and never overwrites an existing file or symlink.
  sayori.editors.seedFiles = [ { inherit target baseline; } ];

}
