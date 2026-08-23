{
  # PipeWire consumes this package/service for bounded real-time scheduling.
  # It owns no persistent data or network exposure; service state is verified
  # with the desktop audio activation gate.
  security.rtkit.enable = true;
}
