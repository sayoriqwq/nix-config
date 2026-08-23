{ config, ... }:

{
  # The Standalone app owns the macOS package and vendor network extension.
  # Login, device identity, routes, MagicDNS, Grants and vendor state remain
  # external mutable control-plane state under ADR-0010's human gates.
  homebrew = {
    enable = true;
    casks = [ "tailscale-app" ];
  };

  assertions = [
    {
      assertion = !config.services.tailscale.enable;
      message = "stable workstation access must use only the Standalone Tailscale macOS app";
    }
  ];
}
