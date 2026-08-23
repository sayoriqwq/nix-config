{
  # PipeWire owns its packages/services, the workstation audio graph and
  # PulseAudio compatibility. Device selection, routing, volumes and user
  # sockets remain mutable runtime state; no network port is opened. Activation
  # requires microphone, speaker and session-service readback.
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
