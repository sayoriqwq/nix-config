{ lib, ... }:

{
  imports = [
    ./fish.nix
  ];

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = lib.mkDefault false;
    options = [
      "--cmd"
      "cd"
    ];
  };
}
