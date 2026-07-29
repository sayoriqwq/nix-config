{
  pkgs,
  username,
  ...
}:

{
  programs.fish.enable = true;
  users.users.${username}.shell = pkgs.fish;

  home-manager.users.${username}.imports = [
    ../../home/capabilities/portable-shell.nix
  ];
}
