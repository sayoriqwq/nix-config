{
  clashVergeRevPackage,
  username,
  ...
}:

{
  home-manager.users.${username}.imports = [ ./linux-home.nix ];

  programs.clash-verge = {
    enable = true;
    package = clashVergeRevPackage;
    serviceMode = true;
    tunMode = false;
    autoStart = false;
    group = "clash-verge";
  };

  users.groups.clash-verge = { };
  users.users.${username}.extraGroups = [ "clash-verge" ];
}
