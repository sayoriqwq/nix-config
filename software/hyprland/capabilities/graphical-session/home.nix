{ lib, ... }:

let
  lua = lib.generators.mkLuaInline;

  workspaceBinds = lib.concatMap (
    workspace:
    let
      key = if workspace == 10 then "0" else toString workspace;
      target = toString workspace;
    in
    [
      {
        _args = [
          "SUPER + ${key}"
          (lua "hl.dsp.focus({ workspace = ${target} })")
        ];
      }
      {
        _args = [
          "SUPER + SHIFT + ${key}"
          (lua "hl.dsp.window.move({ workspace = ${target} })")
        ];
      }
    ]
  ) (lib.range 1 10);
in
{
  imports = [ ../../../../modules/home/common/shortcut-reference.nix ];

  wayland.windowManager.hyprland = {
    enable = true;
    package = null;
    portalPackage = null;
    configType = "lua";
    plugins = [ ];

    # UWSM owns the graphical session and environment import. Running Home
    # Manager's second Hyprland target would create two competing owners.
    systemd.enable = false;

    settings = {
      terminal._var = "uwsm app -- ghostty";
      menu._var = "uwsm app -- fuzzel";
      mainMod._var = "SUPER";

      monitor = {
        output = "";
        mode = "preferred";
        position = "auto";
        scale = "auto";
      };

      config = {
        general.layout = "dwindle";

        input = {
          kb_layout = "us";
          kb_variant = "";
        };
      };

      bind = [
        {
          _args = [
            (lua ''mainMod .. " + Q"'')
            (lua "hl.dsp.exec_cmd(terminal)")
          ];
        }
        {
          _args = [
            (lua ''mainMod .. " + R"'')
            (lua "hl.dsp.exec_cmd(menu)")
          ];
        }
        {
          _args = [
            (lua ''mainMod .. " + C"'')
            (lua "hl.dsp.window.close()")
          ];
        }
        {
          _args = [
            (lua ''mainMod .. " + V"'')
            (lua ''hl.dsp.window.float({ action = "toggle" })'')
          ];
        }
        {
          _args = [
            (lua ''mainMod .. " + L"'')
            (lua ''hl.dsp.exec_cmd("loginctl lock-session")'')
          ];
        }
        {
          _args = [
            (lua ''mainMod .. " + SHIFT + M"'')
            (lua ''hl.dsp.exec_cmd("uwsm stop")'')
          ];
        }
        {
          _args = [
            (lua ''mainMod .. " + left"'')
            (lua ''hl.dsp.focus({ direction = "left" })'')
          ];
        }
        {
          _args = [
            (lua ''mainMod .. " + right"'')
            (lua ''hl.dsp.focus({ direction = "right" })'')
          ];
        }
        {
          _args = [
            (lua ''mainMod .. " + up"'')
            (lua ''hl.dsp.focus({ direction = "up" })'')
          ];
        }
        {
          _args = [
            (lua ''mainMod .. " + down"'')
            (lua ''hl.dsp.focus({ direction = "down" })'')
          ];
        }
        {
          _args = [
            (lua ''mainMod .. " + mouse:272"'')
            (lua "hl.dsp.window.drag()")
            { mouse = true; }
          ];
        }
        {
          _args = [
            (lua ''mainMod .. " + mouse:273"'')
            (lua "hl.dsp.window.resize()")
            { mouse = true; }
          ];
        }
      ]
      ++ workspaceBinds;
    };
  };

  sayori.shortcuts = [
    {
      scope = "Hyprland";
      keys = "Super+Q";
      action = "启动 Ghostty";
      owner = "hyprland";
      order = 300;
    }
    {
      scope = "Hyprland";
      keys = "Super+R";
      action = "打开 Fuzzel 应用启动器";
      owner = "hyprland";
      order = 301;
    }
    {
      scope = "Hyprland";
      keys = "Super+L";
      action = "锁定当前会话";
      owner = "hyprland";
      order = 302;
    }
    {
      scope = "Hyprland";
      keys = "Super+Shift+M";
      action = "正常退出 UWSM 管理的 Hyprland 会话";
      owner = "hyprland";
      order = 303;
    }
  ];
}
