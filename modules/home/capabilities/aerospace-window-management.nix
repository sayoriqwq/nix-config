{ lib, pkgs, ... }:

let
  hyper = "cmd-alt-ctrl";
  workspaces = lib.range 1 10;
  workspaceKey = workspace: if workspace == 10 then "0" else toString workspace;

  workspaceBindings = builtins.listToAttrs (
    lib.concatMap (
      workspace:
      let
        key = workspaceKey workspace;
        target = toString workspace;
      in
      [
        (lib.nameValuePair "${hyper}-${key}" "workspace ${target}")
        (lib.nameValuePair "${hyper}-shift-${key}" "move-node-to-workspace ${target}")
      ]
    ) workspaces
  );
in
{
  imports = [ ../common/shortcut-reference.nix ];

  programs.aerospace = {
    enable = true;
    package = pkgs.aerospace;

    # The first trial is deliberately manual. Enabling Home Manager's agent
    # would start AeroSpace during activation and cross the human launch gate.
    launchd.enable = false;

    settings = {
      config-version = 2;
      start-at-login = false;
      after-login-command = [ ];
      auto-reload-config = false;

      default-root-container-layout = "tiles";
      default-root-container-orientation = "auto";
      enable-normalization-flatten-containers = true;
      enable-normalization-opposite-orientation-for-nested-containers = true;

      # App-specific rules require live bundle-id and window evidence. Keep the
      # first build auditable and rely only on AeroSpace's built-in heuristics.
      on-window-detected = [ ];

      mode = {
        main.binding = {
          "${hyper}-left" = "focus left";
          "${hyper}-down" = "focus down";
          "${hyper}-up" = "focus up";
          "${hyper}-right" = "focus right";
          "${hyper}-v" = "layout floating tiling";
          "${hyper}-esc" = "enable off";
        }
        // workspaceBindings;
      };
    };
  };

  sayori.shortcuts = [
    {
      scope = "AeroSpace（Caps Lock → Hyper）";
      keys = "Hyper+方向键";
      action = "按方向聚焦窗口";
      owner = "aerospace-window-management";
      order = 200;
    }
    {
      scope = "AeroSpace（Caps Lock → Hyper）";
      keys = "Hyper+1…0";
      action = "切换到工作区 1…10";
      owner = "aerospace-window-management";
      order = 201;
    }
    {
      scope = "AeroSpace（Caps Lock → Hyper）";
      keys = "Hyper+Shift+1…0";
      action = "移动当前窗口到工作区 1…10";
      owner = "aerospace-window-management";
      order = 202;
    }
    {
      scope = "AeroSpace（Caps Lock → Hyper）";
      keys = "Hyper+V";
      action = "切换当前窗口的浮动/平铺布局";
      owner = "aerospace-window-management";
      order = 203;
    }
    {
      scope = "AeroSpace（Caps Lock → Hyper）";
      keys = "Hyper+Esc";
      action = "关闭 AeroSpace 接管并恢复隐藏工作区窗口可见";
      owner = "aerospace-window-management";
      order = 204;
    }
  ];
}
