{
  config,
  lib,
  pkgs,
  terminalTheme,
  ...
}:

let
  appearance = import ../../../../modules/home/desktop/terminal/appearance.nix;
  keybindings = import ../../../../modules/home/desktop/terminal/keybindings.nix { inherit lib; };
  theme = terminalTheme.terminal;
  palette = lib.imap0 (index: color: "${toString index}=${color}") (theme.ansi ++ theme.brights);
in
{
  imports = [
    ../../../yume-design/capabilities/terminal-theme/home.nix
    ../../../../modules/home/common/shortcut-reference.nix
  ];

  home.packages = lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    pkgs.maple-mono.NF-CN
  ];

  programs.ghostty = {
    enable = true;
    package = if pkgs.stdenv.hostPlatform.isDarwin then pkgs.ghostty-bin else pkgs.ghostty;

    # Ghostty automatically integrates the initially launched Fish process.
    # Manual Home Manager injection is deliberately disabled for both shells.
    enableFishIntegration = false;
    enableZshIntegration = false;

    settings = {
      theme = terminalTheme.id;
      command = "direct:${lib.getExe config.programs.fish.package} -l";
      "font-family" = appearance.fontFamily;
      "font-size" = appearance.fontSize;
      "window-padding-x" = 20;
      "background-opacity" = appearance.backgroundOpacity;
      "background-opacity-cells" = true;
      "background-blur" = appearance.backgroundBlur;
    }
    // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
      "auto-update" = "off";
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

  sayori.shortcuts = keybindings.shortcuts;
}
