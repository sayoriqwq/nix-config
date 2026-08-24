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
in
{
  programs.wezterm = {
    enable = true;
    package = pkgs.wezterm;
    enableZshIntegration = true;

    settings = {
      automatically_reload_config = true;
      check_for_updates = false;
      color_scheme = terminalTheme.id;
      default_prog = [
        (lib.getExe config.programs.zsh.package)
        "-l"
      ];
      enable_tab_bar = false;
      font = lib.generators.mkLuaInline ''wezterm.font("${appearance.fontFamily}")'';
      font_size = appearance.fontSize;
      keys = keybindings.wezterm;
      window_background_opacity = appearance.backgroundOpacity;
    }
    // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
      macos_window_background_blur = appearance.backgroundBlur;
      window_decorations = "RESIZE";
    };

    colorSchemes.${terminalTheme.id} = {
      inherit (theme) ansi brights;
      inherit (theme) background foreground;
      cursor_bg = theme.cursor;
      cursor_border = theme.cursor;
      cursor_fg = theme.cursorText;
      selection_bg = theme.selectionBackground;
      selection_fg = theme.selectionForeground;
    };
  };
}
