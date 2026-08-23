{ username, ... }:

{
  home-manager.users.${username}.imports = [ ./home.nix ];
}
