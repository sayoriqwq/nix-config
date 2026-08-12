{
  lib,
  macbookConfiguration,
  nixboxConfiguration,
  pkgs,
  serverConfiguration,
  source,
}:

let
  macbook = macbookConfiguration.config;
  nixbox = nixboxConfiguration.config;
  server = serverConfiguration.config;

  caskName = cask: if builtins.isString cask then cask else cask.name;
  caskCount =
    name: builtins.length (builtins.filter (cask: caskName cask == name) macbook.homebrew.casks);
  tailscaleCasks = builtins.filter (
    cask: lib.hasInfix "tailscale" (lib.toLower (caskName cask))
  ) macbook.homebrew.casks;
  packageName = package: package.pname or (lib.getName package);
  hasPackage = name: packages: lib.any (package: packageName package == name) packages;
  sortedPorts = lib.sort (left: right: left < right);
  containsForbiddenFlag = flags: lib.any (flag: lib.hasInfix "--ssh" flag) flags;

  nixboxTailscale = nixbox.services.tailscale;
  nixboxTailscaleFlags =
    nixboxTailscale.extraDaemonFlags ++ nixboxTailscale.extraSetFlags ++ nixboxTailscale.extraUpFlags;
in
assert lib.assertMsg (
  caskCount "tailscale-app" == 1
) "macbook must declare exactly one official Tailscale Standalone cask";
assert lib.assertMsg (
  map caskName tailscaleCasks == [ "tailscale-app" ]
) "macbook must not install another Tailscale variant beside Standalone";
assert lib.assertMsg (
  lib.filterAttrs (name: _: lib.hasInfix "tailscale" (lib.toLower name)) macbook.homebrew.masApps
  == { }
) "macbook must not install a second Tailscale variant from the App Store";
assert lib.assertMsg (
  macbook.homebrew.onActivation.cleanup == "none"
) "macbook Tailscale adoption must not enable destructive Homebrew cleanup";
assert lib.assertMsg (
  !macbook.services.tailscale.enable
) "macbook must not enable nix-darwin's open-source tailscaled owner";
assert lib.assertMsg (
  !macbook.services.tailscale.overrideLocalDns
) "macbook must not let the disabled nix-darwin adapter override local DNS";
assert lib.assertMsg (
  lib.filterAttrs (name: _: lib.hasInfix "tailscale" (lib.toLower name)) macbook.launchd.daemons
  == { }
) "macbook must not create a second Tailscale launch daemon";

assert lib.assertMsg nixboxTailscale.enable "nixbox must enable the locked NixOS Tailscale daemon";
assert lib.assertMsg (
  nixboxTailscale.useRoutingFeatures == "none"
) "nixbox must not enable Tailscale routing features";
assert lib.assertMsg (
  nixbox.networking.firewall.checkReversePath == true
  && !(nixbox.boot.kernel.sysctl ? "net.ipv4.conf.all.forwarding")
  && !(nixbox.boot.kernel.sysctl ? "net.ipv6.conf.all.forwarding")
) "nixbox must not loosen reverse-path filtering or enable packet forwarding";
assert lib.assertMsg (
  nixboxTailscale.authKeyFile == null
) "nixbox enrollment credentials must stay outside Nix and the Store";
assert lib.assertMsg (
  nixboxTailscale.extraUpFlags == [ ]
) "nixbox must not automate tailscale up or enrollment flags";
assert lib.assertMsg (
  nixboxTailscale.extraDaemonFlags == [ ]
) "nixbox must keep the stock tailscaled daemon behavior";
assert lib.assertMsg (
  nixboxTailscale.extraSetFlags == [ "--hostname=nixbox" ]
) "nixbox must declare only the approved stable overlay machine name";
assert lib.assertMsg (
  !containsForbiddenFlag nixboxTailscaleFlags
) "nixbox must keep native OpenSSH instead of enabling Tailscale SSH";
assert lib.assertMsg (
  nixbox.systemd.services ? tailscaled
  && nixbox.systemd.services ? tailscaled-set
  && !(nixbox.systemd.services ? tailscaled-autoconnect)
) "nixbox must run tailscaled and its hostname convergence without automated enrollment";
assert lib.assertMsg (
  builtins.elem nixboxTailscale.package nixbox.systemd.packages
  && builtins.elem "NetworkManager-wait-online.service" nixbox.systemd.services.tailscaled.after
  && builtins.elem "multi-user.target" nixbox.systemd.services.tailscaled.wantedBy
) "nixbox must use the locked upstream unit after NetworkManager is online";
assert lib.assertMsg (
  nixbox.systemd.services.tailscaled-set.script
  == "${lib.getExe nixboxTailscale.package} set '--hostname=nixbox'\n"
) "nixbox must converge only the approved Tailscale machine name";
assert lib.assertMsg (
  !nixbox.systemd.services.tailscaled.stopIfChanged
) "nixbox activation must use the upstream restart strategy instead of stopping tailscaled early";
assert lib.assertMsg (
  nixboxTailscale.port == 41641 && nixboxTailscale.openFirewall
) "nixbox must expose only Tailscale's default direct-path UDP port";
assert lib.assertMsg (
  nixbox.networking.hostName == "nixos"
) "the Tailscale machine name must not replace nixbox's established OS hostname";
assert lib.assertMsg (
  sortedPorts nixbox.networking.firewall.allowedTCPPorts == [
    22
    53317
  ]
) "nixbox Tailscale must not change the established TCP firewall surface";
assert lib.assertMsg (
  sortedPorts nixbox.networking.firewall.allowedUDPPorts == [
    5353
    41641
    53317
  ]
) "nixbox firewall must preserve its baseline and add only UDP 41641";
assert lib.assertMsg (
  nixbox.networking.firewall.trustedInterfaces == [ "lo" ]
  && !builtins.elem "tailscale0" nixbox.networking.firewall.trustedInterfaces
) "nixbox must not trust the complete Tailscale interface";
assert lib.assertMsg (
  nixbox.services.openssh.enable
  && nixbox.services.openssh.settings.PasswordAuthentication == false
  && nixbox.services.openssh.settings.KbdInteractiveAuthentication == false
  && nixbox.services.openssh.settings.PermitRootLogin == "no"
  && nixbox.services.openssh.ports == [ 22 ]
) "nixbox must preserve native key-only OpenSSH and disabled root login";
assert lib.assertMsg (hasPackage "tailscale" nixbox.environment.systemPackages)
  "nixbox must expose the native Tailscale CLI alongside the daemon";

assert lib.assertMsg (
  !server.services.tailscale.enable
) "server must remain outside the workstation Tailscale mesh";
assert lib.assertMsg (
  !hasPackage "tailscale" server.environment.systemPackages
) "server must not receive the Tailscale package";
assert lib.assertMsg (
  !hasPackage "frp" nixbox.environment.systemPackages
  && !hasPackage "frp" server.environment.systemPackages
) "stable workstation access must not introduce an FRP package";
assert lib.assertMsg (
  !(server.systemd.services ? tailscaled)
) "server must not receive a tailscaled service";
assert lib.assertMsg (
  !(server.systemd.services ? tailscaled-set) && !(server.systemd.services ? tailscaled-autoconnect)
) "server must not receive Tailscale preference or enrollment services";
assert lib.assertMsg (
  lib.filterAttrs (name: _: lib.hasPrefix "frp" (lib.toLower name)) nixbox.systemd.services == { }
  && lib.filterAttrs (name: _: lib.hasPrefix "frp" (lib.toLower name)) server.systemd.services == { }
) "stable workstation access must not introduce FRP services";
assert lib.assertMsg (
  sortedPorts server.networking.firewall.allowedTCPPorts == [ 22 ]
) "server TCP firewall must remain unchanged";
assert lib.assertMsg (
  server.networking.firewall.allowedUDPPorts == [ ]
) "server UDP firewall must remain unchanged";
assert lib.assertMsg (
  server.networking.firewall.trustedInterfaces == [ "lo" ]
) "server must not trust a workstation overlay interface";
pkgs.runCommand "stable-workstation-access-policy"
  {
    nativeBuildInputs = [
      pkgs.gnugrep
    ];
  }
  ''
    set -euo pipefail

    count_import() {
      file="$1"
      adapter="$2"
      count="$(grep -F -c "$adapter" "$file" || true)"
      test "$count" = 1 || {
        printf '%s must import %s exactly once (found %s)\n' "$file" "$adapter" "$count" >&2
        exit 1
      }
    }

    count_import ${source}/hosts/macbook/default.nix \
      '../../modules/capabilities/stable-workstation-access/darwin.nix'
    count_import ${source}/hosts/nixbox/default.nix \
      '../../modules/capabilities/stable-workstation-access/nixos.nix'

    tailscaled_unit=${nixboxTailscale.package.src}/cmd/tailscaled/tailscaled.service
    grep -Fqx 'StateDirectory=tailscale' "$tailscaled_unit"
    grep -Fq -- '--state=/var/lib/tailscale/tailscaled.state' "$tailscaled_unit"

    if grep -F -q 'stable-workstation-access' ${source}/hosts/server/default.nix; then
      printf 'server must not import stable-workstation-access\n' >&2
      exit 1
    fi

    touch "$out"
  ''
