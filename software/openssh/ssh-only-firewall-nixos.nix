{
  # The server exposes only OpenSSH. Keep the exact firewall policy explicit
  # here instead of relying on OpenSSH's implicit firewall mutation.
  services.openssh.openFirewall = false;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
    allowedUDPPorts = [ ];
  };
}
