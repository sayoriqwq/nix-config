{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.packages = lib.optionals (!pkgs.stdenv.hostPlatform.isDarwin) [ pkgs.obsidian ];

  # The native macOS bundle owns updates; vaults and preferences stay external.
  home.file.".local/bin/obsidian" = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    source = config.lib.file.mkOutOfStoreSymlink "/Applications/Obsidian.app/Contents/MacOS/Obsidian";
  };
}
