{ config, lib, ... }:

lib.mkIf config.programs.zsh.enable {
  programs.starship.enableZshIntegration = true;
}
