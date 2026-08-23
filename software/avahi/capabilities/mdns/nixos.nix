{
  # Avahi owns its package/daemon and mDNS configuration. It has no declared
  # persistent data, but does own the NixOS UDP 5353 firewall opening.
  # Activation must read back both avahi-daemon and that unchanged exposure;
  # this module does not own general network configuration.
  services.avahi = {
    enable = true;
    openFirewall = true;
  };
}
