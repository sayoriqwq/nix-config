{
  # Capability contract (NixOS): package = rtkit from the NixOS security module;
  # managed configuration = bounded realtime scheduling enabled; mutable-state
  # paths = none; services = rtkit-daemon; network effects = none; human gate =
  # daemon and audio scheduling readback in the desktop-audio activation gate.
  security.rtkit.enable = true;
}
