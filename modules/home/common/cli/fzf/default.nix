{
  imports = [
    ./fish.nix
    ./zsh.nix
  ];

  programs.fzf.enable = true;

  # fzf treats an explicitly empty value as "do not bind Ctrl+R". Atuin is
  # the sole enhanced-history owner; Ctrl+T and Alt+C remain fzf defaults.
  home.sessionVariables.FZF_CTRL_R_COMMAND = "";

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
