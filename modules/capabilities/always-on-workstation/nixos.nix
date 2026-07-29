{
  lib,
  username,
  ...
}:

{
  services.displayManager.gdm.autoSuspend = false;

  programs.dconf.profiles.gdm.databases = [
    {
      settings."org/gnome/desktop/session".idle-delay = lib.gvariant.mkUint32 0;
    }
  ];

  home-manager.users.${username}.imports = [ ./home.nix ];
}
