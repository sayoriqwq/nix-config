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
[
  {
    key = "d";
    mods = "SUPER";
    action = lua ''act.SplitHorizontal { domain = "CurrentPaneDomain" }'';
  }
  {
    key = "d";
    mods = "SHIFT|SUPER";
    action = lua ''act.SplitVertical { domain = "CurrentPaneDomain" }'';
  }
  {
    key = "Enter";
    mods = "SHIFT|SUPER";
    action = lua "act.TogglePaneZoomState";
  }
]
++ map (binding: {
  inherit (binding) key;
  mods = "ALT|SUPER";
  action = lua ''act.ActivatePaneDirection "${binding.direction}"'';
}) directions
++ map (binding: {
  inherit (binding) key;
  mods = "CTRL|SUPER";
  action = lua ''act.AdjustPaneSize { "${binding.direction}", 10 }'';
}) directions
