{
  # Capability contract (NixOS): package = Avahi from the NixOS service module;
  # managed configuration = mDNS enabled with its explicit firewall option;
  # mutable-state paths = none declared (runtime discovery cache is ephemeral);
  # services = avahi-daemon; network effects = UDP 5353; human gate = activation
  # must read back both the daemon and unchanged firewall exposure.
  services.avahi = {
    enable = true;
    openFirewall = true;
  };
}
