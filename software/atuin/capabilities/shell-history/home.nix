{
  config,
  lib,
  ...
}:

{
  imports = [
    ../../../../modules/home/common/shortcut-reference.nix
    ../../../../modules/home/common/state-paths.nix
  ];

  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = lib.mkDefault false;
    flags = [ "--disable-up-arrow" ];
    settings = {
      key_path = "~/.local/share/atuin/key";
      search_mode = "daemon-fuzzy";

      daemon = {
        enabled = true;
        autostart = true;
      };
    };
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

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.local/share/atuin";
      owner = "Atuin";
      backup = "required";
      description = "Local history database, encryption key and daemon state.";
    }
  ];

  # The standalone installer used to prepend ~/.atuin/bin. Replacing that
  # snippet makes the Home Manager package authoritative while preserving
  # Atuin's writable database, key and daemon state.
  xdg.configFile."fish/conf.d/atuin.env.fish".text = ''
    # Atuin is provided by Home Manager; mutable Atuin state remains unmanaged.
  '';
}
