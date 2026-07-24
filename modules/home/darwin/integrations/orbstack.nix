{ lib, ... }:

{
  # OrbStack installation and mutable container state belong to its dedicated
  # migration issue. This module only preserves the current platform hook.
  programs.fish.interactiveShellInit = lib.mkAfter ''
    test -f "$HOME/.orbstack/shell/init2.fish"; and source "$HOME/.orbstack/shell/init2.fish"
  '';

  programs.zsh.profileExtra = ''
    [[ -f "$HOME/.orbstack/shell/init.zsh" ]] && source "$HOME/.orbstack/shell/init.zsh"
  '';
}
