{
  # Capability contract (NixOS): package = GNOME Keyring from the NixOS service
  # module; managed configuration = Secret Service/login-PAM enablement;
  # mutable-state path = ~/.local/share/keyrings via the Home attachment;
  # services = gnome-keyring user/login integration; network effects = none;
  # human gate = local login, unlock and secret-service smoke after activation.
  services.gnome.gnome-keyring.enable = true;
}
