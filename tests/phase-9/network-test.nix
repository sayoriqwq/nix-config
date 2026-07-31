{
  inputs,
  phase9Preflight,
  pkgs,
  serverModules,
  username,
}:

let
  values = import ./values.nix;
  sshOptions = "-o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/root/.ssh/known_hosts -o HostKeyAlgorithms=ssh-ed25519 -o ConnectTimeout=5";
in
pkgs.testers.runNixOSTest {
  name = "phase9-server-network-access";
  globalTimeout = 900;
  node.pkgsReadOnly = false;
  node.specialArgs = {
    inherit inputs username;
  };

  nodes = {
    server =
      { lib, pkgs, ... }:
      {
        imports = serverModules ++ [ ./server-overlay.nix ];
        _module.args.phase9ConfigureWithoutCarrier = false;
        _module.args.phase9NetworkDriver = "virtio_net";

        boot.loader.grub.enable = lib.mkForce false;
        disko.enableConfig = lib.mkForce false;
        environment.systemPackages = [
          phase9Preflight
          pkgs.netcat-openbsd
        ];

        virtualisation = {
          cores = 1;
          interfaces.uplink0 = {
            assignIP = false;
            vlan = 9;
          };
          memorySize = 1536;
        };
      };

    gateway =
      { lib, pkgs, ... }:
      {
        networking = {
          firewall.enable = false;
          hostName = "phase9-gateway";
          interfaces = lib.mkForce { };
          useDHCP = false;
          useNetworkd = true;
        };

        services = {
          dnsmasq = {
            enable = true;
            settings = {
              bind-interfaces = true;
              interface = "gateway0";
              listen-address = [
                values.ipv4Dns
                values.ipv6Dns
              ];
              no-resolv = true;
              address = [
                "/phase9.internal/${values.ipv4Gateway}"
                "/phase9.internal/2001:db8:9::1"
              ];
            };
          };
          resolved.enable = false;
        };

        systemd.network = {
          enable = true;
          networks."10-phase9-gateway" = {
            matchConfig.Name = "gateway0";
            addresses = [
              { Address = "${values.ipv4Gateway}/24"; }
              { Address = "${values.ipv4Dns}/24"; }
              { Address = "2001:db8:9::1/64"; }
              { Address = "${values.ipv6Dns}/64"; }
              { Address = "${values.ipv6Gateway}/64"; }
            ];
            networkConfig = {
              DHCP = "no";
              IPv6AcceptRA = false;
              LinkLocalAddressing = "no";
            };
            linkConfig.RequiredForOnline = "routable";
          };
        };

        environment.systemPackages = [
          pkgs.iproute2
          pkgs.netcat-openbsd
          pkgs.openssh
        ];

        virtualisation = {
          cores = 1;
          interfaces.gateway0 = {
            assignIP = false;
            vlan = 9;
          };
          memorySize = 512;
        };
      };

    ambiguous =
      { pkgs, ... }:
      {
        networking = {
          hostName = "phase9-ambiguous";
          useDHCP = false;
          useNetworkd = true;
        };

        systemd.network = {
          enable = true;
          networks."10-phase9-ambiguous" = {
            matchConfig.Driver = "virtio_net";
            networkConfig = {
              DHCP = "no";
              IPv6AcceptRA = false;
              LinkLocalAddressing = "no";
            };
          };
        };

        environment.systemPackages = [ phase9Preflight ];

        virtualisation = {
          cores = 1;
          interfaces = {
            uplink0 = {
              assignIP = false;
              vlan = 9;
            };
            uplink1 = {
              assignIP = false;
              vlan = 10;
            };
          };
          memorySize = 512;
        };
      };
  };

  testScript = ''
    import shlex

    with subtest("preflight fails closed and serial console stays available"):
        ambiguous.start()
        ambiguous.wait_for_unit("multi-user.target")
        ambiguous.fail("PHASE9_EXPECTED_NIC_COUNT=1 phase9-vm-preflight")
        ambiguous.succeed("PHASE9_EXPECTED_NIC_COUNT=2 phase9-vm-preflight")
        ambiguous.fail("PHASE9_EXPECTED_BOOT_MODE=uefi PHASE9_EXPECTED_NIC_COUNT=2 phase9-vm-preflight")
        ambiguous.fail("PHASE9_EXPECTED_NIC_COUNT=2 PHASE9_EXPECTED_DISK=/dev/phase9-missing phase9-vm-preflight")
        ambiguous.succeed("echo console-recovery-path-available")
        ambiguous.shutdown()

    gateway.start()
    server.start(allow_reboot=True)
    gateway.wait_for_unit("multi-user.target")
    gateway.wait_for_unit("dnsmasq.service")
    server.wait_for_unit("multi-user.target")
    server.wait_for_unit("sshd.service")

    with subtest("isolated dummy dual-stack topology and DNS"):
        server.succeed("phase9-vm-preflight")
        server.succeed("ip -4 -o address show dev uplink0 | grep -F '${values.ipv4Address}'")
        server.succeed("ip -6 -o address show dev uplink0 | grep -F '${values.ipv6Address}'")
        server.succeed("ip -4 route show default | grep -F 'via ${values.ipv4Gateway}'")
        server.succeed("ip -6 route show default | grep -F 'via ${values.ipv6Gateway}'")
        server.succeed("ping -c 1 -W 2 ${values.ipv4Gateway}")
        server.succeed("ping -6 -c 1 -W 2 '${values.ipv6Gateway}%uplink0'")
        server.succeed("resolvectl query phase9.internal | grep -F '${values.ipv4Gateway}'")
        server.succeed("resolvectl query phase9.internal | grep -F '2001:db8:9::1'")
        gateway.succeed("nc -z -w 2 ${values.ipv4Host} 22")
        gateway.succeed("nc -6 -z -w 2 ${values.ipv6Host} 22")

    with subtest("runtime-only client keys and simulated host-key copy"):
        gateway.succeed("install -d -m 0700 /root/.ssh")
        gateway.succeed("ssh-keygen -q -t ed25519 -N \"\" -C phase9-runtime-maintenance -f /root/.ssh/maintenance")
        gateway.succeed("ssh-keygen -q -t ed25519 -N \"\" -C phase9-runtime-deploy -f /root/.ssh/deploy")
        maintenance_key = gateway.succeed("cat /root/.ssh/maintenance.pub").strip()
        deploy_key = gateway.succeed("cat /root/.ssh/deploy.pub").strip()

        server.succeed("install -d -m 0700 -o ${username} -g users /home/${username}/.ssh")
        server.succeed(
            f"printf '%s\\n%s\\n' {shlex.quote(maintenance_key)} {shlex.quote(deploy_key)}"
            " > /home/${username}/.ssh/authorized_keys"
        )
        server.succeed("chown ${username}:users /home/${username}/.ssh/authorized_keys && chmod 0600 /home/${username}/.ssh/authorized_keys")
        server.succeed("install -d -m 0700 /root/.ssh")
        server.succeed(f"printf '%s\\n' {shlex.quote(maintenance_key)} > /root/.ssh/authorized_keys")
        server.succeed("chmod 0600 /root/.ssh/authorized_keys")

        server.succeed("install -d -m 0700 /var/lib/phase9-source-host")
        server.succeed("ssh-keygen -q -t ed25519 -N \"\" -C phase9-source-host -f /var/lib/phase9-source-host/ssh_host_ed25519_key")
        server.succeed("systemctl stop sshd.service")
        server.succeed("install -m 0600 /var/lib/phase9-source-host/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key")
        server.succeed("install -m 0644 /var/lib/phase9-source-host/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_ed25519_key.pub")
        server.succeed("systemctl start sshd.service")
        copied_host_key = server.succeed("cat /etc/ssh/ssh_host_ed25519_key.pub").strip()
        gateway.succeed(
            f"printf '%s %s\\n' '${values.ipv4Host}' {shlex.quote(copied_host_key)}"
            " > /root/.ssh/known_hosts"
        )

        gateway.succeed("ssh ${sshOptions} -i /root/.ssh/maintenance ${username}@${values.ipv4Host} true")
        gateway.succeed("ssh ${sshOptions} -i /root/.ssh/deploy ${username}@${values.ipv4Host} true")
        gateway.succeed("ssh ${sshOptions} -i /root/.ssh/maintenance ${username}@${values.ipv4Host} sudo -n true")
        gateway.succeed("ssh ${sshOptions} -i /root/.ssh/maintenance root@${values.ipv4Host} true")
        gateway.fail("ssh ${sshOptions} -i /root/.ssh/deploy root@${values.ipv4Host} true")
        gateway.fail("ssh ${sshOptions} -o PubkeyAuthentication=no -o PreferredAuthentications=password ${username}@${values.ipv4Host} true")
        gateway.fail("ssh ${sshOptions} -o PubkeyAuthentication=no -o PreferredAuthentications=keyboard-interactive ${username}@${values.ipv4Host} true")

    with subtest("firewall exposes SSH and blocks an undeclared listener"):
        server.succeed("systemd-run --unit=phase9-blocked-listener --collect ${pkgs.netcat-openbsd}/bin/nc -l -k 8080")
        server.wait_until_succeeds("ss -lnt | grep -E '[:.]8080[[:space:]]'")
        gateway.fail("nc -z -w 2 ${values.ipv4Host} 8080")
        gateway.fail("nc -6 -z -w 2 ${values.ipv6Host} 8080")

    with subtest("second boot preserves simulated source identity and access"):
        first_boot_id = server.succeed("cat /proc/sys/kernel/random/boot_id").strip()
        first_host_key = server.succeed("cat /etc/ssh/ssh_host_ed25519_key.pub").strip()
        server.reboot()
        server.wait_for_unit("multi-user.target")
        server.wait_for_unit("sshd.service")
        second_boot_id = server.succeed("cat /proc/sys/kernel/random/boot_id").strip()
        second_host_key = server.succeed("cat /etc/ssh/ssh_host_ed25519_key.pub").strip()
        assert first_boot_id != second_boot_id
        assert first_host_key == second_host_key
        gateway.succeed("ssh ${sshOptions} -i /root/.ssh/maintenance ${username}@${values.ipv4Host} true")
        gateway.succeed("ssh ${sshOptions} -i /root/.ssh/deploy ${username}@${values.ipv4Host} sudo -n true")
        gateway.succeed("nc -6 -z -w 2 ${values.ipv6Host} 22")

    with subtest("ephemeral test credentials are removed before shutdown"):
        gateway.succeed("rm -f /root/.ssh/maintenance /root/.ssh/maintenance.pub /root/.ssh/deploy /root/.ssh/deploy.pub /root/.ssh/known_hosts")
        server.succeed("systemctl stop sshd.service")
        server.succeed("rm -f /home/${username}/.ssh/authorized_keys /root/.ssh/authorized_keys")
        server.succeed("rm -f /var/lib/phase9-source-host/ssh_host_ed25519_key /var/lib/phase9-source-host/ssh_host_ed25519_key.pub")
        server.succeed("rmdir /var/lib/phase9-source-host")
        server.succeed("rm -f /etc/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key.pub")
        server.succeed("test ! -e /var/lib/phase9-source-host && test ! -e /etc/ssh/ssh_host_ed25519_key")
        server.shutdown()
        gateway.shutdown()
  '';
}
