{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    dnsutils
    lsof
    mtr
    tcpdump
    strace
  ];
}
