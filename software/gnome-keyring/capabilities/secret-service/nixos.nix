{
  # Preserve the Secret Service and login-PAM integration without enabling the
  # GNOME desktop. Keyring contents remain mutable user state.
  services.gnome.gnome-keyring.enable = true;
}
