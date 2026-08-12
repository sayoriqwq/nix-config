{ config, ... }:

{
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
