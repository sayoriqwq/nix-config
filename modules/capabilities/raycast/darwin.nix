{ username, ... }:

{
  homebrew = {
    enable = true;
    casks = [ "raycast" ];
  };

  home-manager.users.${username}.imports = [ ./home.nix ];
}
