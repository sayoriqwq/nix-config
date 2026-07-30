{
  networking = {
    hostName = "server";
    useDHCP = false;
    useNetworkd = true;
  };

  services.resolved.enable = true;

  systemd.network = {
    enable = true;
    networks."10-contabo-uplink" = {
      matchConfig.Driver = "virtio_net";

      addresses = [
        { Address = "38.242.129.34/21"; }
        { Address = "2a02:c207:2301:9930::1/64"; }
      ];

      routes = [
        { Gateway = "38.242.128.1"; }
        {
          Gateway = "fe80::1";
          GatewayOnLink = true;
        }
      ];

      networkConfig = {
        DHCP = "no";
        IPv6AcceptRA = false;
        LinkLocalAddressing = "ipv6";
        DNS = [
          "213.136.95.10"
          "213.136.95.11"
          "2a02:c207::1:53"
        ];
      };

      linkConfig.RequiredForOnline = "routable";
    };
  };
}
