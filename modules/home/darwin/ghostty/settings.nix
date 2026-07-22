{ config, lib, ... }:

{
  programs.ghostty.settings = {
    theme = "sayoriqwq-obsidian";
    command = "direct:${lib.getExe config.programs.fish.package} -l";

    "font-family" = "Maple Mono NF CN";
    "font-size" = 20;

    "macos-titlebar-style" = "tabs";
    "macos-window-buttons" = "hidden";
    "window-padding-x" = 20;

    "background-opacity" = 0.95;
    "background-opacity-cells" = true;
    "background-blur" = 10;
  };
}
