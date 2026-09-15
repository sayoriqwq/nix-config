{ lib, ... }:

{
  programs.direnv = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = lib.mkDefault false;
    nix-direnv.enable = true;
  };
}
