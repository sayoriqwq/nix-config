{ config, ... }:

{
  # 独立应用及其网络扩展维护连接状态，避免与第二个 tailscaled 冲突。
  homebrew = {
    enable = true;
    casks = [ "tailscale-app" ];
  };

  assertions = [
    {
      assertion = !config.services.tailscale.enable;
      message = "stable workstation access must use only the Standalone Tailscale macOS app";
    }
  ];
}
