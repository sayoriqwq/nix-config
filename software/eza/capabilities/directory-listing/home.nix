{ lib, ... }:

{
  programs.eza = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = lib.mkDefault false;
    icons = "auto";
  };
}
