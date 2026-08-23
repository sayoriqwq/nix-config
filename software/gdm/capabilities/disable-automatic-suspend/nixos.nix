{
  # The always-on intent selects this contribution explicitly. Activation must
  # verify that GDM remains reachable while unattended suspend stays disabled.
  services.displayManager.gdm.autoSuspend = false;
}
