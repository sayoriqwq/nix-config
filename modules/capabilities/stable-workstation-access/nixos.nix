{
  services.tailscale = {
    enable = true;
    port = 41641;
    openFirewall = true;
    useRoutingFeatures = "none";

    # Enrollment stays interactive and outside the Nix Store. The only
    # persisted preference owned here is the overlay machine name.
    authKeyFile = null;
    extraUpFlags = [ ];
    extraSetFlags = [ "--hostname=nixbox" ];
    extraDaemonFlags = [ ];
  };
}
