{
  nixosModules = [
    ../software/bind/nixos.nix
    ../software/lsof/nixos.nix
    ../software/mtr/nixos.nix
    ../software/strace/nixos.nix
    ../software/tcpdump/nixos.nix
  ];
}
