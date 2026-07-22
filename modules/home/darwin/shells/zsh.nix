{ config, lib, ... }:

{
  programs = {
    zsh = {
      enable = true;
      dotDir = config.home.homeDirectory;

      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;

      history = {
        path = "${config.home.homeDirectory}/.zhistory";
        size = 999;
        save = 1000;
        share = true;
        expireDuplicatesFirst = true;
        ignoreDups = true;
        ignoreSpace = false;
      };

      setOptions = [ "HIST_VERIFY" ];

      envExtra = ''
        [[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
      '';

      profileExtra = ''
        [[ -f "$HOME/.orbstack/shell/init.zsh" ]] && source "$HOME/.orbstack/shell/init.zsh"
      '';

      initContent = lib.mkMerge [
        (lib.mkOrder 550 ''
          # Preserve the compatibility environment's existing Darwin tools.
          path=(
            /opt/homebrew/opt/postgresql@16/bin
            "$HOME/.local/bin"
            /opt/homebrew/bin
            $path
            "$HOME/.ghcup/bin"
            "$HOME/.cabal/bin"
          )
        '')

        (lib.mkOrder 800 ''
          if [[ -x /opt/homebrew/bin/mise ]]; then
            eval "$(/opt/homebrew/bin/mise activate zsh)"
          fi
        '')

        (lib.mkOrder 1300 ''
          bindkey '^[[A' history-search-backward
          bindkey '^[[B' history-search-forward
          bindkey '^[[1;5A' atuin-up-search

          if [[ -x /opt/homebrew/bin/thefuck ]]; then
            eval "$(/opt/homebrew/bin/thefuck --alias)"
          fi

          [[ -f "$HOME/.ghcup/env" ]] && source "$HOME/.ghcup/env"

          if [[ -f "$HOME/.openclaw/completions/openclaw.zsh" ]]; then
            source "$HOME/.openclaw/completions/openclaw.zsh"
          fi
        '')
      ];
    };
  };
}
