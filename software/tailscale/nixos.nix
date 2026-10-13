{
  # 设备授权留在主机本地；原生 SSH 仍由 OpenSSH 负责。
  services.tailscale = {
    enable = true;
    port = 41641;
    openFirewall = true;
    useRoutingFeatures = "none";
    authKeyFile = null;
    extraUpFlags = [ ];
    extraSetFlags = [ "--hostname=nixbox" ];
    extraDaemonFlags = [ ];
  };
}
