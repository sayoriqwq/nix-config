{ username, ... }:

{
  home-manager.users.${username}.imports = [ ./darwin-home.nix ];
}
