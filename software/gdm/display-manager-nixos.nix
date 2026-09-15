{
  # Capability contract (NixOS): package = GDM from the NixOS module; managed
  # configuration = GDM enabled and GNOME desktop disabled; mutable-state paths
  # = none declared (login/session state remains externally owned); services =
  # display-manager/GDM; network effects = none; human gate = exact-commit
  # activation plus local login and recovery-path smoke.
  services = {
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = false;
  };
}
