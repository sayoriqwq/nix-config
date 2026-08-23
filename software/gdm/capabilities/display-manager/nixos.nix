{
  # GDM owns the login service without restoring the retired GNOME desktop.
  # Switching display managers is deferred to the exact-commit human gate.
  services = {
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = false;
  };
}
