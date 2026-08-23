{
  # Tailscale owns the nixbox service, /var/lib/tailscale vendor state, stable
  # overlay name and UDP 41641 direct-path firewall opening. It does not own
  # native SSH policy, general DNS/routes or the tailnet control plane. Any
  # activation/enrollment requires the complete ADR-0010 readback gate.
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
