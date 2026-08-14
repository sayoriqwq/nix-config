{
  config,
  pkgs,
  ...
}:

let
  keyboardNavigation = pkgs.callPackage ./package.nix { };
in
{
  imports = [
    ../../home/common/state-paths.nix
    ../../home/common/shortcut-reference.nix
    ./raycast-home.nix
    ./aerospace-home.nix
  ];

  home.packages = [ keyboardNavigation ];

  sayori = {
    statePaths = [
      {
        path = "${config.home.homeDirectory}/.local/state/nix-config/macos-keyboard-navigation";
        owner = "macos-keyboard-navigation reconcile workflow";
        backup = "separate-policy";
        description = "Owner-only exact plist leaves are retained outside the Nix store while a manually approved reconcile remains rollbackable.";
      }
    ];

    shortcuts = [
      {
        scope = "Raycast";
        keys = "Cmd+Space";
        action = "打开 Raycast launcher";
        owner = "macos-keyboard-navigation";
        order = 190;
      }
      {
        scope = "macOS 窗口切换（Caps Lock → Hyper）";
        keys = "Hyper+Space";
        action = "聚焦下一个窗口";
        owner = "macos-keyboard-navigation";
        order = 191;
      }
    ];
  };
}
