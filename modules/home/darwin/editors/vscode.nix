{
  config,
  ...
}:

let
  baseline = ../../desktop/editors/vscode/settings.jsonc;
  target = "${config.home.homeDirectory}/Library/Application Support/Code/User/settings.json";
in
{
  # VS Code and its extensions keep this file writable. Nix provides only a
  # first-run baseline and never overwrites an existing file or symlink.
  sayori.editors.seedFiles = [ { inherit target baseline; } ];
}
