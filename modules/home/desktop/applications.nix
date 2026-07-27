{ pkgs, ... }:

{
  home.packages = with pkgs; [
    atuin-desktop
    discord
    localsend
    obsidian
    upscayl
  ];
}
