{ pkgs, ... }:

{
  home.packages = with pkgs; [
    iina
    monitorcontrol
    mos
    xbar
  ];
}
