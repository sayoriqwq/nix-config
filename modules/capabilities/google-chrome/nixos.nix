{ username, ... }:

{
  home-manager.users.${username}.imports = [ ./linux-home.nix ];
}
