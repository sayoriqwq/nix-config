{ username, ... }:

let
  values = import ./values.nix;
in
{
  disko.tests = {
    efi = false;
    extraConfig = {
      imports = [ ./server-overlay.nix ];

      # disko's boot reconstruction uses QEMU's implicit e1000 NIC and does
      # not expose a virtualisation option for that manually-created machine.
      # The separate network test keeps the production-equivalent virtio_net
      # topology and fail-closed preflight.
      _module.args.phase9NetworkDriver = "e1000";
    };
    extraChecks = ''
      with subtest("BIOS, GPT, EF02, ext4 root and no swap"):
          machine.wait_for_unit("multi-user.target")
          machine.wait_for_unit("sshd.service")
          machine.succeed("test ! -d /sys/firmware/efi")
          machine.succeed("test \"$(lsblk -dn -o TYPE /dev/vda)\" = disk")
          machine.succeed("sgdisk -i 1 /dev/vda | grep -F '21686148-6449-6E6F-744E-656564454649'")
          machine.succeed("test \"$(findmnt -n -o FSTYPE /)\" = ext4")
          machine.succeed("test \"$(lsblk -no FSTYPE /dev/vda2)\" = ext4")
          machine.succeed("test -z \"$(swapon --show --noheadings)\"")

      with subtest("dummy dual-stack network on disko's single e1000 boot NIC"):
          nic = machine.succeed(
              """for nic_path in /sys/class/net/*; do
                    driver_path="$(readlink -f "$nic_path/device/driver" 2>/dev/null || true)"
                    if test "$(basename "$driver_path")" = e1000; then
                      basename "$nic_path"
                    fi
                 done"""
          ).strip()
          assert nic != ""
          assert "\n" not in nic
          machine.succeed(f"ip -4 -o address show dev {shlex.quote(nic)} | grep -F '${values.ipv4Address}'")
          machine.succeed(f"ip -6 -o address show dev {shlex.quote(nic)} | grep -F '${values.ipv6Address}'")
          machine.succeed("ip -4 route show default | grep -F 'via ${values.ipv4Gateway}'")
          machine.succeed("ip -6 route show default | grep -F 'via ${values.ipv6Gateway}'")
          machine.succeed(f"resolvectl dns {shlex.quote(nic)} | grep -F '${values.ipv4Dns}'")
          machine.succeed(f"resolvectl dns {shlex.quote(nic)} | grep -F '${values.ipv6Dns}'")

      with subtest("users, sudo, SSH policy and minimal firewall"):
          machine.succeed("grep -Fx '${values.maintenancePublicKey}' /etc/ssh/authorized_keys.d/${username}")
          machine.succeed("grep -Fx '${values.deployPublicKey}' /etc/ssh/authorized_keys.d/${username}")
          machine.succeed("test \"$(wc -l < /etc/ssh/authorized_keys.d/${username})\" -eq 2")
          machine.succeed("grep -Fx '${values.maintenancePublicKey}' /etc/ssh/authorized_keys.d/root")
          machine.succeed("test \"$(wc -l < /etc/ssh/authorized_keys.d/root)\" -eq 1")
          machine.succeed("runuser -u ${username} -- sudo -n true")
          machine.succeed("sshd -T | grep -Fx 'passwordauthentication no'")
          machine.succeed("sshd -T | grep -Fx 'kbdinteractiveauthentication no'")
          machine.succeed("sshd -T | grep -Fx 'permitrootlogin prohibit-password'")
          machine.succeed("systemctl is-active firewall.service")
          machine.succeed("ss -lnt | grep -E '[:.]22[[:space:]]'")
          machine.fail("ss -lnt | grep -E '[:.](80|443)[[:space:]]'")

      with subtest("headless capability boundary"):
          machine.fail("runuser -u ${username} -- sh -lc 'command -v gh'")
          machine.fail("runuser -u ${username} -- sh -lc 'command -v zed'")
          machine.fail("runuser -u ${username} -- sh -lc 'command -v google-chrome-stable'")
          machine.fail("command -v docker")
          machine.fail("systemctl list-unit-files --no-legend | grep -E '^(display-manager|docker|podman)\\.'")
          machine.fail("runuser -u ${username} -- grep -Eq '^[[:space:]]*sync([._]|[[:space:]]*=)' /home/${username}/.config/atuin/config.toml")

      with subtest("second boot preserves access-critical state"):
          first_boot_id = machine.succeed("cat /proc/sys/kernel/random/boot_id").strip()
          first_host_key = machine.succeed("ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub").strip()
          machine.reboot()
          machine.wait_for_unit("multi-user.target")
          machine.wait_for_unit("sshd.service")
          second_boot_id = machine.succeed("cat /proc/sys/kernel/random/boot_id").strip()
          second_host_key = machine.succeed("ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub").strip()
          assert first_boot_id != second_boot_id
          assert first_host_key == second_host_key
          machine.succeed("test \"$(findmnt -n -o FSTYPE /)\" = ext4")
          machine.succeed("test -z \"$(swapon --show --noheadings)\"")
          machine.succeed("ip -4 route show default | grep -F 'via ${values.ipv4Gateway}'")
          machine.succeed("ip -6 route show default | grep -F 'via ${values.ipv6Gateway}'")
          machine.succeed("runuser -u ${username} -- sudo -n true")
    '';
  };
}
