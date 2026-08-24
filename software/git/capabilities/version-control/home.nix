{ pkgs, ... }:

{
  home.packages = [ pkgs.delta ];

  programs.git = {
    enable = true;
    # Identity remains a private writable include outside Nix and Git.
    includes = [ { path = "~/.config/git/identity.inc"; } ];
  };
}
