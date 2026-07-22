{ lib }:

{
  automatically_reload_config = true;
  default_prog = [
    "/bin/zsh"
    "-l"
  ];
  enable_tab_bar = false;
  font = lib.generators.mkLuaInline ''wezterm.font("Maple Mono NF CN")'';
  font_size = 20;
  window_decorations = "RESIZE";
}
