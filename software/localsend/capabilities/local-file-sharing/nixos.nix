{ username, ... }:

{
  home-manager.users.${username}.imports = [ ./home.nix ];

  networking.firewall = {
    allowedTCPPorts = [ 53317 ];
    allowedUDPPorts = [ 53317 ];
  };
}
