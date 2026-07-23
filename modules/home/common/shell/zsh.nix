{ lib, ... }:

{
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
}
