{
  # Capability contract (NixOS attachment): package = none beyond the Home
  # owner; managed configuration = Hyprlock PAM policy; mutable-state paths =
  # none; services = PAM integration only; network effects = none; human gate =
  # target-machine lock/unlock and password-safety smoke.
  security.pam.services.hyprlock = { };
}
