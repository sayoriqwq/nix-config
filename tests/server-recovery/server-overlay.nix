{
  lib,
  serverRecoveryConfigureWithoutCarrier,
  serverRecoveryNetworkDriver,
  pkgs,
  username,
  ...
}:

let
  values = import ./values.nix;
in
{
  networking = {
    hostName = lib.mkForce "server-recovery";
    interfaces = lib.mkForce { };
    useDHCP = lib.mkForce false;
    useNetworkd = lib.mkForce true;
  };

  services.resolved.enable = lib.mkForce true;

  systemd.network = {
    enable = lib.mkForce true;
    networks = lib.mkForce {
      "10-server-recovery-uplink" = {
        matchConfig.Driver = serverRecoveryNetworkDriver;

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
          ConfigureWithoutCarrier = serverRecoveryConfigureWithoutCarrier;
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

    root.openssh.authorizedKeys.keys = lib.mkForce [ ];
  };

  environment.systemPackages = [
    pkgs.gptfdisk
    pkgs.iproute2
    pkgs.netcat-openbsd
    pkgs.openssh
    pkgs.util-linux
  ];
}
