{ username, ... }:

{
  home-manager.users.${username}.imports = [ ./home-manager.nix ];

  networking.firewall = {
    allowedTCPPorts = [ 53317 ];
    allowedUDPPorts = [ 53317 ];
  };
}
