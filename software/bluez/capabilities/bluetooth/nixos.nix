{
  # Capability contract (NixOS): package = BlueZ from the NixOS Bluetooth
  # module; managed configuration = controller support enabled; mutable-state
  # path = /var/lib/bluetooth, externally owned; services = bluetooth.service;
  # network effects = none in the IP firewall; human gate = controller and
  # paired-device smoke tests on the target machine.
  hardware.bluetooth.enable = true;
}
