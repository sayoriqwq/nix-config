{
  imports = [
    ./fish.nix
    ./zsh.nix
  ];

  programs.lazygit = {
    enable = true;
    shellWrapperName = "lg";
    settings.keybinding.universal.quitWithoutChangingDirectory = "Q";
  };

  sayori.shortcuts = [
    {
      scope = "Fish / Zsh";
      keys = "lg";
      action = "启动 lazygit；正常退出后同步工作目录";
      owner = "lazygit";
      order = 50;
    }
    {
      scope = "lazygit";
      keys = "Shift+Q";
      action = "退出且不把 lazygit 工作目录同步回 Shell";
      owner = "lazygit";
      order = 51;
    }
  ];
}
