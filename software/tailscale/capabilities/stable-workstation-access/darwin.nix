{ config, ... }:

{
  # Capability contract (Darwin): package = Standalone tailscale-app cask;
  # managed configuration = cask presence plus the no-second-service assertion;
  # mutable-state paths = none declared because the vendor path is unproven;
  # services = external app/network extension; network effects = vendor overlay,
  # DNS/routes per external state; human gate = ADR-0010 activation/enrollment,
  # connectivity and rollback readback.
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
