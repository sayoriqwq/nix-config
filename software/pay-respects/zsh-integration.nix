{ config, lib, ... }:

lib.mkIf config.programs.zsh.enable {
  programs.pay-respects.enableZshIntegration = true;
}
