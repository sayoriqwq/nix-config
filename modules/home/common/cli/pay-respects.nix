{
  programs.pay-respects = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
    options = [
      "--alias"
      "f"
    ];
  };

  sayori.shortcuts = [
    {
      scope = "Fish / Zsh";
      keys = "f";
      action = "让 pay-respects 修正上一条失败命令";
      owner = "pay-respects";
      order = 40;
    }
  ];
}
