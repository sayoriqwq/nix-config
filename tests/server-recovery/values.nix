{
  ipv4Address = "192.0.2.10/24";
  ipv4Host = "192.0.2.10";
  ipv4Gateway = "192.0.2.1";
  ipv4Dns = "192.0.2.53";

  ipv6Address = "2001:db8:9::10/64";
  ipv6Host = "2001:db8:9::10";
  ipv6Gateway = "fe80::1";
  ipv6Dns = "2001:db8:9::53";

  maintenancePublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFU5z1+fZ1fiyBcFBwCoDluFGnDxu6c7a6hVagtmrvpE server-recovery-maintenance-slot";
  deployPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINz12gN/B5joRZtJx4hsqf2q0rEWgSvE9TJLYBGLcJ9L server-recovery-deploy-slot";
}
