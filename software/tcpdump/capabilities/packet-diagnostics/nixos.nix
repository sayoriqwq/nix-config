{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.tcpdump ];
}
