{ lib, options, ... }:

let
  hasStructuredHistoryWidget = lib.hasAttrByPath [
    "programs"
    "fzf"
    "historyWidget"
    "command"
  ] options;
in
{
  imports = [
    ./fish.nix
  ];

  programs.fzf = {
    enable = true;
  }
  // lib.optionalAttrs hasStructuredHistoryWidget {
    historyWidget.command = "";
  };

  # Home Manager 26.11 models the history widget directly. The 26.05 module
  # still consumes the legacy environment variable. Both declarations mean
  # "do not bind Ctrl+R": Atuin remains the sole enhanced-history owner.
  home.sessionVariables = lib.optionalAttrs (!hasStructuredHistoryWidget) {
    FZF_CTRL_R_COMMAND = "";
  };

  sayori.shortcuts = [
    {
      scope = "Fish / Zsh";
      keys = "Ctrl+T";
      action = "用 fzf 选择文件并插入命令行";
      owner = "fzf";
      order = 30;
    }
    {
      scope = "Fish / Zsh";
      keys = "Alt+C";
      action = "用 fzf 选择目录并进入";
      owner = "fzf";
      order = 31;
    }
  ];
}
