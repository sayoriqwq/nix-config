{
  # 主 SSH 配置需 Include 此片段；凭据和 known_hosts 保持本地可写。
  home.file.".ssh/config.d/nixbox-tailscale.conf".text = ''
    Host nixbox
      ProxyCommand /usr/bin/env TAILSCALE_BE_CLI=1 /Applications/Tailscale.app/Contents/MacOS/Tailscale nc %h %p
  '';
}
