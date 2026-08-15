{ lib, pkgs, ... }:

let
  modifier = "ctrl";
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
        (lib.nameValuePair "${modifier}-${key}" "workspace ${target}")
        (lib.nameValuePair "${modifier}-shift-${key}" "move-node-to-workspace ${target}")
      ]
    ) workspaces
  );
in
{
  programs.aerospace = {
    enable = true;
    package = pkgs.aerospace;

    # Activation must not cross the first-launch and Accessibility gates.
    launchd.enable = false;

    settings = {
      config-version = 2;
      start-at-login = false;
      after-login-command = [ ];
      auto-reload-config = false;

      accordion-padding = 0;
      default-root-container-layout = "tiles";
      default-root-container-orientation = "auto";
      enable-normalization-flatten-containers = true;
      enable-normalization-opposite-orientation-for-nested-containers = true;

      # App-specific rules require live bundle-id and window evidence.
      on-window-detected = [ ];

      mode = {
        main.binding = {
          "${modifier}-left" = "focus left";
          "${modifier}-down" = "focus down";
          "${modifier}-up" = "focus up";
          "${modifier}-right" = "focus right";
          "${modifier}-tab" = "layout accordion tiles";
          "${modifier}-v" = "layout floating tiling";
          "${modifier}-esc" = "enable off";
        }
        // workspaceBindings;
      };
    };
  };

  sayori.shortcuts = [
    {
      scope = "AeroSpace（macOS 键盘导航）";
      keys = "Ctrl+方向键";
      action = "按方向聚焦窗口";
      owner = "macos-keyboard-navigation";
      order = 200;
    }
    {
      scope = "AeroSpace（macOS 键盘导航）";
      keys = "Ctrl+1…0";
      action = "切换到工作区 1…10";
      owner = "macos-keyboard-navigation";
      order = 201;
    }
    {
      scope = "AeroSpace（macOS 键盘导航）";
      keys = "Ctrl+Shift+1…0";
      action = "移动当前窗口到工作区 1…10";
      owner = "macos-keyboard-navigation";
      order = 202;
    }
    {
      scope = "AeroSpace（macOS 键盘导航）";
      keys = "Ctrl+V";
      action = "切换当前窗口的浮动/平铺布局";
      owner = "macos-keyboard-navigation";
      order = 203;
    }
    {
      scope = "AeroSpace（macOS 键盘导航）";
      keys = "Ctrl+Esc";
      action = "关闭 AeroSpace 接管并恢复隐藏工作区窗口可见";
      owner = "macos-keyboard-navigation";
      order = 204;
    }
  ];
}
