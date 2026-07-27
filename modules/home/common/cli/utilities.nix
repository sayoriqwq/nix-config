{ pkgs, ... }:

{
  home.packages = with pkgs; [
    delta
    fastfetch
    gitleaks
    graphviz
    poppler-utils
    rclone
    rtk
    yazi
  ];
}
