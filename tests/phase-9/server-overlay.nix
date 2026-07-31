{
  lib,
  pkgs,
  username,
  ...
}:

let
  values = import ./values.nix;
in
{
  networking = {
    hostName = lib.mkForce "server-phase9";
    interfaces = lib.mkForce { };
    useDHCP = lib.mkForce false;
    useNetworkd = lib.mkForce true;
  };

  services.resolved.enable = lib.mkForce true;

  systemd.network = {
    enable = lib.mkForce true;
    networks = lib.mkForce {
      "10-phase9-uplink" = {
        matchConfig.Driver = "virtio_net";

        addresses = [
          { Address = values.ipv4Address; }
          { Address = values.ipv6Address; }
        ];

        routes = [
          { Gateway = values.ipv4Gateway; }
          {
            Gateway = values.ipv6Gateway;
            GatewayOnLink = true;
          }
        ];

        networkConfig = {
          DHCP = "no";
          IPv6AcceptRA = false;
          LinkLocalAddressing = "ipv6";
          DNS = [
            values.ipv4Dns
            values.ipv6Dns
          ];
        };

        linkConfig.RequiredForOnline = "routable";
      };
    };
  };

  users.users = {
    ${username}.openssh.authorizedKeys.keys = lib.mkForce [
      values.maintenancePublicKey
      values.deployPublicKey
    ];

    root.openssh.authorizedKeys.keys = lib.mkForce [
      values.maintenancePublicKey
    ];
  };

  environment.systemPackages = [
    pkgs.gptfdisk
    pkgs.iproute2
    pkgs.netcat-openbsd
    pkgs.openssh
    pkgs.util-linux
  ];
}
