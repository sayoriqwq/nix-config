{ username, ... }:

{
  homebrew.casks = [ "raycast" ];

  home-manager.users.${username}.imports = [ ./home-manager.nix ];
}
