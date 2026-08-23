{
  # Hyprlock needs a system PAM policy to unlock the current user session.
  # Authentication behavior must be exercised only in the machine-local gate.
  security.pam.services.hyprlock = { };
}
