{ config, lib, ... }:

lib.mkIf config.programs.zsh.enable {
  programs.lazygit.enableZshIntegration = true;
}
