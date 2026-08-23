{
  # Capability contract (NixOS): package = Tailscale from the NixOS module;
  # managed configuration = daemon, port and stable overlay name below;
  # mutable-state path = /var/lib/tailscale, vendor-owned; services = tailscaled;
  # network effects = UDP 41641 plus vendor overlay chains, with no native SSH
  # ownership; human gate = ADR-0010 activation/enrollment and full readback.
  services.tailscale = {
    enable = true;
    port = 41641;
    openFirewall = true;
    useRoutingFeatures = "none";
    authKeyFile = null;
    extraUpFlags = [ ];
    extraSetFlags = [ "--hostname=nixbox" ];
    extraDaemonFlags = [ ];
  };
}
