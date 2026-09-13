{
  config,
  lib,
  pkgs,
  ...
}:

let
  baseline =
    if pkgs.stdenv.hostPlatform.isDarwin then
      pkgs.writeText "vscode-settings.jsonc" (
        builtins.replaceStrings [ ''"update.mode": "none"'' ] [ ''"update.mode": "default"'' ] (
          builtins.readFile ./settings.jsonc
        )
      )
    else
      ./settings.jsonc;
  target = "${config.home.homeDirectory}/Library/Application Support/Code/User/settings.json";
in
{
  imports = [
    ../../../../modules/home/desktop/editors/seed-files.nix
  ];

  home.packages = lib.optionals (!pkgs.stdenv.hostPlatform.isDarwin) [ pkgs.vscode ];

  # The native macOS bundle owns updates; CLI calls use that same installation.
  home.file.".local/bin/code" = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    source = config.lib.file.mkOutOfStoreSymlink "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code";
  };

  # VS Code and its extensions keep this file writable. Nix provides only a
  # first-run baseline and never overwrites an existing file or symlink.
  sayori.editors.seedFiles = [ { inherit target baseline; } ];

}
