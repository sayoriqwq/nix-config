{
  # Capability contract (Home Manager): package = hyprpolkitagent from the Home
  # Manager service; managed configuration = enablement only; mutable-state
  # paths = none; services = its user authentication-agent service; network
  # effects = none; human gate = local authorization-prompt smoke after activation.
  services.hyprpolkitagent.enable = true;
}
