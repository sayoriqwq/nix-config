{ lib, ... }:

{
  programs.fish.interactiveShellInit = lib.mkAfter ''
    test -f "$HOME/.orbstack/shell/init2.fish"; and source "$HOME/.orbstack/shell/init2.fish"
  '';

  programs.zsh.profileExtra = ''
    [[ -f "$HOME/.orbstack/shell/init.zsh" ]] && source "$HOME/.orbstack/shell/init.zsh"
  '';
}
