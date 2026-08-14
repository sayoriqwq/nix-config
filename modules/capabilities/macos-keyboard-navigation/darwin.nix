{ username, ... }:

{
  # Raycast supplies the launcher and Caps Lock Hyper producer for this
  # capability. Its settings and mutable data remain application-owned.
  homebrew = {
    enable = true;
    casks = [ "raycast" ];
  };

  # This is the capability's only host interface. The Home Manager side owns
  # Raycast source deployment, AeroSpace, and the explicit side-effect tool.
  home-manager.users.${username}.imports = [ ./home.nix ];
}
