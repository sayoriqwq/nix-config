{
  imports = [
    ./fish.nix
    ./zsh.nix
  ];

  sayori.shortcuts = [
    {
      scope = "Fish / Zsh";
      keys = "↑ / ↓";
      action = "按当前输入前缀浏览原生 Shell 历史";
      owner = "shell";
      order = 10;
    }
  ];
}
