{ config, lib, ... }:

lib.mkIf config.programs.zsh.enable {
  programs.atuin.enableZshIntegration = true;
}
