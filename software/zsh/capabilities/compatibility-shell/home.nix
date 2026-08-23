{ config, lib, ... }:

{
  imports = [
    ../../../../modules/home/common/state-paths.nix
    ../../../../modules/home/darwin/hushlogin.nix
  ];

  programs.zsh = {
    enable = true;

    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    history = {
      path = "$HOME/.zhistory";
      size = 999;
      save = 1000;
      share = true;
      expireDuplicatesFirst = true;
      ignoreDups = true;
      ignoreSpace = false;
    };

    setOptions = [ "HIST_VERIFY" ];

    initContent = lib.mkOrder 1300 ''
      bindkey '^[[A' history-search-backward
      bindkey '^[[B' history-search-forward
    '';
  };

  sayori.shortcuts = [
    {
      scope = "Zsh";
      keys = "↑ / ↓";
      action = "按当前输入前缀浏览原生 Shell 历史";
      owner = "zsh";
      order = 11;
    }
  ];

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.zhistory";
      owner = "Zsh";
      backup = "required";
      description = "Writable compatibility-shell history; Fish remains the primary shell.";
    }
  ];
}
