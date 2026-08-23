{
  # Capability contract (Home Manager): package = Fuzzel from the Home Manager
  # module; managed configuration = enablement only; mutable-state paths = none;
  # services = none; network effects = none; human gate = activation and launch
  # smoke remain part of the exact-commit desktop gate.
  programs.fuzzel.enable = true;
}
