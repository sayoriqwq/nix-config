{
  # Capability contract (Darwin Home Manager): package = none because the
  # Darwin adapter owns the Standalone app; managed configuration = this
  # non-secret OpenSSH fragment; mutable state = the external main SSH config
  # and known_hosts remain user-owned; services = none; network effects = an
  # on-demand Tailscale TCP stream; human gate = activation, one-time Include,
  # fresh login environment and native OpenSSH readback.
  home.file.".ssh/config.d/nixbox-tailscale.conf".text = ''
    Host nixbox
      ProxyCommand /usr/bin/env TAILSCALE_BE_CLI=1 /Applications/Tailscale.app/Contents/MacOS/Tailscale nc %h %p
  '';
}
