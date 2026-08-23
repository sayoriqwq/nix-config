{ username, ... }:

{
  services.displayManager.gdm.autoSuspend = false;

  home-manager.users.${username}.imports = [ ./home.nix ];
}
