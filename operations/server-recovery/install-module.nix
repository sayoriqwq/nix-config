{
  lib,
  username,
  ...
}:

{
  networking.hostName = lib.mkForce "server-recovery-install";

  disko = {
    devices.disk.main.device = lib.mkForce "/dev/vda";
    tests.extraChecks = ''
      with subtest("isolated BIOS and disk layout"):
          machine.wait_for_unit("multi-user.target")
          machine.wait_for_unit("sshd.service")
          machine.succeed("test ! -d /sys/firmware/efi")
          machine.succeed("test \"$(findmnt -n -o FSTYPE /)\" = ext4")
          machine.succeed("test -z \"$(swapon --show --noheadings)\"")
          machine.succeed("sgdisk -i 1 /dev/vda | grep -F '21686148-6449-6E6F-744E-656564454649'")

      with subtest("production access policy survives the isolated install"):
          machine.succeed("runuser -u ${username} -- sudo -n true")
          machine.succeed("sshd -T -f /etc/ssh/sshd_config -h /etc/ssh/ssh_host_ed25519_key | grep -Fxi 'passwordauthentication no'")
          machine.succeed("sshd -T -f /etc/ssh/sshd_config -h /etc/ssh/ssh_host_ed25519_key | grep -Fxi 'kbdinteractiveauthentication no'")
          machine.succeed("sshd -T -f /etc/ssh/sshd_config -h /etc/ssh/ssh_host_ed25519_key | grep -Fxi 'permitrootlogin no'")
          machine.succeed("systemctl is-active firewall.service")
    '';
  };

  systemd.network.networks = lib.mkForce {
    "10-server-recovery-install" = {
      matchConfig.Type = "ether";
      addresses = [
        { Address = "192.0.2.10/24"; }
        { Address = "2001:db8:9::10/64"; }
      ];
      networkConfig = {
        ConfigureWithoutCarrier = true;
        DHCP = "no";
        IPv6AcceptRA = false;
        LinkLocalAddressing = "ipv6";
      };
      linkConfig.RequiredForOnline = "no";
    };
  };

  users.users.${username}.openssh.authorizedKeys.keys = lib.mkForce [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBQ443MIvcDxNVk/b6oe31GW4wafxGHA1PBZPMr5H+zy server-recovery-maintenance-test"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM7j+h/bd4xCL/3mJeKLfk/josBF2wlejDX22/cOmq5B server-recovery-deploy-test"
  ];
}
