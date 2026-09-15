{
  # Capability contract (NixOS): package = Xorg server from the NixOS module;
  # managed configuration = server enablement plus US XKB layout; mutable-state
  # paths = none; services = X server/display-manager integration; network effects
  # = none; human gate = local XWayland/XKB compatibility smoke after activation.
  services.xserver = {
    enable = true;
    xkb = {
      layout = "us";
      variant = "";
    };
  };
}
