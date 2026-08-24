{
  # Capability contract (NixOS): package = Hyprland from the NixOS module;
  # managed configuration = UWSM and XWayland enablement; mutable-state paths =
  # none (runtime sockets/session are ephemeral); services = UWSM graphical
  # session; network effects = none; human gate = exact-commit login, display
  # and portal smoke on the target machine.
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };
}
