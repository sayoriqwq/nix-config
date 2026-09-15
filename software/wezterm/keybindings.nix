{ lib }:

let
  lua = lib.generators.mkLuaInline;
  directions = [
    {
      key = "LeftArrow";
      direction = "Left";
    }
    {
      key = "DownArrow";
      direction = "Down";
    }
    {
      key = "RightArrow";
      direction = "Right";
    }
    {
      key = "UpArrow";
      direction = "Up";
    }
  ];
in
{
  wezterm = [
    {
      key = "d";
      mods = "SUPER";
      action = lua ''wezterm.action.SplitHorizontal { domain = "CurrentPaneDomain" }'';
    }
    {
      key = "d";
      mods = "SHIFT|SUPER";
      action = lua ''wezterm.action.SplitVertical { domain = "CurrentPaneDomain" }'';
    }
    {
      key = "Enter";
      mods = "SHIFT|SUPER";
      action = lua "wezterm.action.TogglePaneZoomState";
    }
  ]
  ++ map (binding: {
    inherit (binding) key;
    mods = "ALT|SUPER";
    action = lua ''wezterm.action.ActivatePaneDirection "${binding.direction}"'';
  }) directions
  ++ map (binding: {
    inherit (binding) key;
    mods = "CTRL|SUPER";
    action = lua ''wezterm.action.AdjustPaneSize { "${binding.direction}", 10 }'';
  }) directions
  ++ [
    {
      key = "Enter";
      mods = "SUPER";
      action = lua "wezterm.action.ToggleFullScreen";
    }
    {
      key = "P";
      mods = "SHIFT|SUPER";
      action = lua "wezterm.action.ActivateCommandPalette";
    }
    {
      key = "UpArrow";
      mods = "SUPER";
      action = lua "wezterm.action.ScrollToPrompt(-1)";
    }
    {
      key = "DownArrow";
      mods = "SUPER";
      action = lua "wezterm.action.ScrollToPrompt(1)";
    }
  ];
}
