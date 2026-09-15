{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.strace ];
}
