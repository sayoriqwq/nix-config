{ config, lib, ... }:

lib.mkIf config.programs.zsh.enable {
  programs.mise.enableZshIntegration = true;
}
