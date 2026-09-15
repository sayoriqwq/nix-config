{ lib, ... }:

{
  programs.pay-respects = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = lib.mkDefault false;
    options = [
      "--alias"
      "f"
    ];
  };
}
