{
  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
    flags = [ "--disable-up-arrow" ];
  };

  sayori.shortcuts = [
    {
      scope = "Fish / Zsh";
      keys = "Ctrl+R";
      action = "打开 Atuin 增强历史搜索";
      owner = "atuin";
      order = 20;
    }
  ];

  # The standalone installer used to prepend ~/.atuin/bin. Replacing that
  # snippet makes the Home Manager package authoritative while preserving
  # Atuin's writable database, key and daemon state.
  xdg.configFile."fish/conf.d/atuin.env.fish".text = ''
    # Atuin is provided by Home Manager; mutable Atuin state remains unmanaged.
  '';
}
