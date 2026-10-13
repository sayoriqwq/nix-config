{ pkgs, ... }:

{
  environment.systemPackages = [
    pkgs.qt5.qtwayland
    pkgs.qt6.qtwayland
  ];
}
