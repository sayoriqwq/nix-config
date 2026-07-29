{ pkgs, ... }:

{
  home.packages = with pkgs; [
    discord
    iina
    monitorcontrol
    mos
    upscayl
    xbar
  ];
}
