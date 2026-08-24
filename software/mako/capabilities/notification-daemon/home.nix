{
  # Capability contract (Home Manager): package = Mako from the Home Manager
  # service; managed configuration = enablement only; mutable-state paths = none;
  # services = Mako user notification daemon; network effects = none; human gate
  # = local D-Bus notification smoke after activation.
  services.mako.enable = true;
}
