{
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
    allowedUDPPorts = [ ];
  };

  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    openFirewall = false;
    settings.PermitRootLogin = "no";
  };
}
