{
  # Capability contract (NixOS extension): package = none beyond the selected
  # GDM owner; managed configuration = autoSuspend=false; mutable-state paths =
  # none; services = the existing GDM display-manager service; network effects
  # = none; human gate = activation must verify GDM reachability and suspend.
  services.displayManager.gdm.autoSuspend = false;
}
