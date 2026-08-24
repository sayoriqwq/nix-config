{
  # Capability contract (NixOS): package = PipeWire/WirePlumber from the NixOS
  # module; managed configuration = ALSA, 32-bit ALSA and Pulse compatibility;
  # mutable-state paths = none declared (routing, volume and sockets are runtime
  # state); services = PipeWire/WirePlumber user services; network effects =
  # none; human gate = microphone, speaker and session-service readback.
  services = {
    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };
}
