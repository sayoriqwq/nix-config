{ config, lib, ... }:

lib.mkIf config.programs.zsh.enable {
  programs.fzf.enableZshIntegration = true;
}
