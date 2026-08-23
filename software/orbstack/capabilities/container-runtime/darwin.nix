{ username, ... }:

{
  homebrew.casks = [ "orbstack" ];

  home-manager.users.${username}.imports = [ ./home.nix ];
}
