{
  inputs,
  pkgs,
  self,
  serverModules,
  username,
}:

pkgs.testers.runNixOSTest {
  name = "server-recovery-network";

  node.specialArgs = {
    inherit inputs self username;
  };
  node.pkgsReadOnly = false;

  nodes = {
    gateway =
      { lib, pkgs, ... }:
      {
        environment.systemPackages = [
          pkgs.netcat-openbsd
          pkgs.openssh
        ];

        networking = {
          firewall.enable = false;
          hostName = "server-recovery-gateway";
          useDHCP = false;
          useNetworkd = true;
        };

        system.stateVersion = "26.05";

        systemd.network = {
          enable = true;
          networks."10-server-recovery-gateway" = {
            matchConfig.Driver = "virtio_net";
            addresses = [
              { Address = "192.0.2.1/24"; }
              { Address = "2001:db8:9::1/64"; }
            ];
            networkConfig = {
              DHCP = "no";
              IPv6AcceptRA = false;
              LinkLocalAddressing = "ipv6";
            };
            linkConfig.RequiredForOnline = "routable";
          };
        };

        virtualisation = {
          graphics = false;
          interfaces.eth1 = {
            assignIP = false;
            vlan = 1;
          };
          memorySize = 512;
          qemu.networkingOptions = lib.mkForce [ ];
        };
      };

    server =
      { lib, pkgs, ... }:
      {
        imports = serverModules;

        disko.enableConfig = lib.mkForce false;

        environment.systemPackages = [
          pkgs.netcat-openbsd
          pkgs.openssh
        ];

        networking.hostName = lib.mkForce "server-recovery-network";

        services.openssh.authorizedKeysFiles = lib.mkForce [
          "/run/server-recovery-authorized-keys/%u"
        ];

        systemd.network.networks = lib.mkForce {
          "10-server-recovery-uplink" = {
            matchConfig.Driver = "virtio_net";
            addresses = [
              { Address = "192.0.2.2/24"; }
              { Address = "2001:db8:9::2/64"; }
            ];
            networkConfig = {
              DHCP = "no";
              IPv6AcceptRA = false;
              LinkLocalAddressing = "ipv6";
            };
            linkConfig.RequiredForOnline = "routable";
          };
        };

        systemd.tmpfiles.rules = [
          "d /run/server-recovery-authorized-keys 0755 root root -"
        ];

        users.users.${username}.openssh.authorizedKeys.keys = lib.mkForce [ ];

        virtualisation = {
          graphics = false;
          interfaces.eth1 = {
            assignIP = false;
            vlan = 1;
          };
          memorySize = 1536;
          qemu.networkingOptions = lib.mkForce [ ];
        };
      };
  };

  testScript =
    { nodes, ... }:
    ''
      import shlex

      start_all()
      gateway.wait_for_unit("network-online.target")
      server.wait_for_unit("sshd.service")

      with subtest("isolated dual-stack transport"):
          gateway.wait_until_succeeds("ping -c 1 192.0.2.2")
          gateway.wait_until_succeeds("ping -6 -c 1 2001:db8:9::2")
          gateway.succeed("nc -z -w 5 192.0.2.2 22")
          gateway.succeed("nc -6 -z -w 5 2001:db8:9::2 22")

      with subtest("ephemeral maintenance and deploy identities"):
          gateway.succeed("install -d -m 0700 /root/.ssh")
          gateway.succeed("ssh-keygen -q -t ed25519 -N \"\" -C maintenance-test -f /root/.ssh/maintenance")
          gateway.succeed("ssh-keygen -q -t ed25519 -N \"\" -C deploy-test -f /root/.ssh/deploy")
          maintenance_key = gateway.succeed("cat /root/.ssh/maintenance.pub").strip()
          deploy_key = gateway.succeed("cat /root/.ssh/deploy.pub").strip()
          server.succeed(
              "printf '%s\\n%s\\n' "
              + shlex.quote(maintenance_key)
              + " "
              + shlex.quote(deploy_key)
              + " > /run/server-recovery-authorized-keys/${username}"
          )
          server.succeed("chmod 0644 /run/server-recovery-authorized-keys/${username}")
          gateway.succeed("ssh-keyscan -H 192.0.2.2 > /root/.ssh/known_hosts")
          gateway.succeed("ssh-keyscan -H 2001:db8:9::2 >> /root/.ssh/known_hosts")

          ssh = (
              "ssh -o BatchMode=yes -o StrictHostKeyChecking=yes "
              "-o UserKnownHostsFile=/root/.ssh/known_hosts"
          )
          gateway.succeed(f"{ssh} -i /root/.ssh/maintenance ${username}@192.0.2.2 true")
          gateway.succeed(f"{ssh} -6 -i /root/.ssh/deploy ${username}@2001:db8:9::2 'sudo -n true'")
          gateway.fail(f"{ssh} -i /root/.ssh/maintenance root@192.0.2.2 true")
          gateway.fail(
              f"{ssh} -o PreferredAuthentications=password "
              "-o PubkeyAuthentication=no ${username}@192.0.2.2 true"
          )

      with subtest("firewall keeps undeclared listeners unreachable"):
          server.succeed(
              "systemd-run --unit=server-recovery-blocked-listener --collect "
              "${pkgs.netcat-openbsd}/bin/nc -l -k 8080"
          )
          server.wait_until_succeeds("ss -lnt | grep -E '[:.]8080[[:space:]]'")
          gateway.fail("nc -z -w 2 192.0.2.2 8080")
          gateway.fail("nc -6 -z -w 2 2001:db8:9::2 8080")

      with subtest("runtime credentials are removed before shutdown"):
          server.succeed("rm -f /run/server-recovery-authorized-keys/${username}")
          gateway.succeed("rm -f /root/.ssh/maintenance /root/.ssh/maintenance.pub /root/.ssh/deploy /root/.ssh/deploy.pub /root/.ssh/known_hosts")
          server.succeed("test ! -e /run/server-recovery-authorized-keys/${username}")
          gateway.succeed("test ! -e /root/.ssh/maintenance")
    '';
}
