{
  config,
  lib,
  pkgs,
  terminalTheme,
  ...
}:

let
  appearance = import ../../../../modules/home/desktop/terminal/appearance.nix;
  theme = terminalTheme.terminal;
  palette = lib.imap0 (index: color: "${toString index}=${color}") (theme.ansi ++ theme.brights);
in
{
  home.packages = lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    pkgs.maple-mono.NF-CN
  ];

  # The native macOS bundle owns updates; keep CLI calls on that same version.
  home.file.".local/bin/ghostty" = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    source = config.lib.file.mkOutOfStoreSymlink "/Applications/Ghostty.app/Contents/MacOS/ghostty";
  };

  programs.ghostty = {
    enable = true;
    package = if pkgs.stdenv.hostPlatform.isDarwin then null else pkgs.ghostty;

    # Ghostty automatically integrates the initially launched Fish process.
    # Manual Home Manager injection is deliberately disabled for both shells.
    enableFishIntegration = false;
    enableZshIntegration = false;

    settings = {
      theme = terminalTheme.id;
      command = "direct:${lib.getExe config.programs.fish.package} -l";
      "font-family" = appearance.fontFamily;
      "font-size" = appearance.fontSize;
      "cursor-style" = "bar";
      "window-padding-x" = 20;
      "background-opacity" = appearance.backgroundOpacity;
      "background-opacity-cells" = true;
      "background-blur" = appearance.backgroundBlur;
    }
    // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
      "macos-titlebar-style" = "tabs";
      "macos-window-buttons" = "hidden";
    };

    themes.${terminalTheme.id} = {
      inherit palette;
      inherit (theme) background foreground;
      "cursor-color" = theme.cursor;
      "cursor-text" = theme.cursorText;
      "selection-background" = theme.selectionBackground;
      "selection-foreground" = theme.selectionForeground;
    };
  };
}
