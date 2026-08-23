{
  # BlueZ owns its package and Bluetooth controller service. Pairings, device
  # trust and /var/lib/bluetooth stay mutable; no firewall port is opened.
  # Controller and paired-device smoke tests remain a machine-local gate.
  hardware.bluetooth.enable = true;
}
