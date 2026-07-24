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

  shortcuts = [
    {
      scope = "Ghostty / WezTerm";
      keys = "Cmd+D";
      action = "向右创建 pane";
      owner = "terminal";
      order = 100;
    }
    {
      scope = "Ghostty / WezTerm";
      keys = "Shift+Cmd+D";
      action = "向下创建 pane";
      owner = "terminal";
      order = 101;
    }
    {
      scope = "Ghostty / WezTerm";
      keys = "Shift+Cmd+Enter";
      action = "缩放或还原当前 pane";
      owner = "terminal";
      order = 102;
    }
    {
      scope = "Ghostty / WezTerm";
      keys = "Alt+Cmd+方向键";
      action = "切换 pane 焦点";
      owner = "terminal";
      order = 103;
    }
    {
      scope = "Ghostty / WezTerm";
      keys = "Ctrl+Cmd+方向键";
      action = "调整 pane 大小";
      owner = "terminal";
      order = 104;
    }
    {
      scope = "Ghostty / WezTerm";
      keys = "Cmd+Enter";
      action = "切换全屏";
      owner = "terminal";
      order = 105;
    }
    {
      scope = "Ghostty / WezTerm";
      keys = "Shift+Cmd+P";
      action = "打开命令面板";
      owner = "terminal";
      order = 106;
    }
    {
      scope = "Ghostty / WezTerm";
      keys = "Cmd+↑ / Cmd+↓";
      action = "在 OSC 133 语义提示区域之间滚动";
      owner = "terminal";
      order = 107;
    }
    {
      scope = "Ghostty";
      keys = "Ctrl+Cmd+=";
      action = "均分所有 pane";
      owner = "terminal";
      order = 108;
    }
  ];
}
