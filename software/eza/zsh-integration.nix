{ config, lib, ... }:

lib.mkIf config.programs.zsh.enable {
  programs.eza.enableZshIntegration = true;
}
