{ config, lib, ... }:

lib.mkIf config.programs.zsh.enable {
  programs.direnv.enableZshIntegration = true;
}
