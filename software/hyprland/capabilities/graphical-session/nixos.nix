{
  # The pinned NixOS module owns the compositor package/config and UWSM system
  # session. Runtime sockets and session state remain ephemeral; this owner
  # opens no network port. Display/login and portal behavior are verified only
  # through the exact-commit machine-local activation gate.
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };
}
