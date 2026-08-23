{
  lib,
  macbookConfiguration,
  nixboxConfiguration,
  packageSource,
  pkgs,
  serverConfiguration,
  source,
  username,
}:

let
  macbook = macbookConfiguration.config;
  nixbox = nixboxConfiguration.config;
  server = serverConfiguration.config;

  clash = nixbox.programs.clash-verge;
  clashPackage = clash.package;
  clashService = nixbox.systemd.services.clash-verge;
  nixboxHome = nixbox.home-manager.users.${username};
  serverHome = server.home-manager.users.${username};

  packageName = package: package.pname or (lib.getName package);
  packageCount =
    name: packages: builtins.length (lib.filter (package: packageName package == name) packages);
  caskName = cask: if builtins.isString cask then cask else cask.name;
  caskCount = name: builtins.length (lib.filter (cask: caskName cask == name) macbook.homebrew.casks);
  statePathsAt = path: lib.filter (entry: entry.path == path) nixboxHome.sayori.statePaths;
  clashStatePaths = statePathsAt "${nixboxHome.home.homeDirectory}/.local/share/io.github.clash-verge-rev.clash-verge-rev";
  sortedPorts = lib.sort (left: right: left < right);
  lock = builtins.fromJSON (builtins.readFile (source + "/flake.lock"));
  rootInput = name: lock.nodes.${lock.nodes.root.inputs.${name}};
in
assert lib.assertMsg (
  (rootInput "clash-verge-rev-package-source").locked.rev
  == "d9e5fe493950fb219c0e7ccd2c0430a3babd77a6"
  && (rootInput "nixpkgs").original.ref == "nixos-26.05"
  && (rootInput "home-manager").original.ref == "release-26.05"
) "Clash must use the exact leaf source without moving the Linux release inputs";
assert lib.assertMsg (
  clash.enable
  && clash.serviceMode
  && !clash.tunMode
  && !clash.autoStart
  && clash.group == "clash-verge"
) "nixbox must use the declared Service Mode without a second GUI capability path";
assert lib.assertMsg (
  clashPackage.version == "2.5.2"
  && clashPackage.src.tag == "v2.5.2"
  && clashPackage.passthru.service.version == "2.3.3"
  && clashPackage.passthru.service.src.tag == "v2.3.3"
) "nixbox must use the reviewed Clash Verge Rev and companion service versions";
assert lib.assertMsg (
  packageCount "clash-verge-rev" nixbox.environment.systemPackages == 1
  && packageCount "clash-verge-rev" nixboxHome.home.packages == 0
) "NixOS must be the only nixbox Clash Verge Rev package owner";
assert lib.assertMsg (
  builtins.length clashStatePaths == 1
  && (builtins.head clashStatePaths).backup == "required"
  && lib.hasInfix "Service Mode" (builtins.head clashStatePaths).description
) "Home Manager must retain exactly one writable Clash Verge Rev state boundary";

assert lib.assertMsg (
  nixbox.systemd.services ? clash-verge
  && clashService.wantedBy == [ "multi-user.target" ]
  && clashService.serviceConfig.ExecStart == "${clashPackage}/bin/clash-verge-service"
  && clashService.serviceConfig.Group == "clash-verge"
  && clashService.serviceConfig.RuntimeDirectory == "clash-verge-rev"
  && (clashService.serviceConfig.User or "root") == "root"
  && clashService.serviceConfig.NoNewPrivileges
  && clashService.serviceConfig.PrivateTmp
  && clashService.serviceConfig.ProtectSystem == "strict"
  &&
    clashService.serviceConfig.CapabilityBoundingSet == [
      "CAP_NET_ADMIN CAP_NET_RAW CAP_SYS_ADMIN CAP_DAC_OVERRIDE CAP_SETUID CAP_SETGID CAP_CHOWN CAP_MKNOD"
    ]
) "nixbox must retain the reviewed root service path, socket group, and hardening";
assert lib.assertMsg (
  nixbox.users.groups ? clash-verge
  && nixbox.users.groups.clash-verge.members == [ username ]
  && builtins.elem "clash-verge" nixbox.users.users.${username}.extraGroups
  && nixbox.programs.clash-verge.group != "users"
  && nixbox.programs.clash-verge.group != "wheel"
) "only the confirmed nixbox user may access the privileged Clash service socket";
assert lib.assertMsg (
  !(nixbox.security.wrappers ? clash-verge)
) "nixbox must not grant network capabilities directly to the Clash GUI";

assert lib.assertMsg (
  !server.programs.clash-verge.enable
  && !(server.systemd.services ? clash-verge)
  && !(server.security.wrappers ? clash-verge)
  && !(server.users.groups ? clash-verge)
  && packageCount "clash-verge-rev" server.environment.systemPackages == 0
  && packageCount "clash-verge-rev" serverHome.home.packages == 0
) "server must remain outside the workstation-only Clash capability";
assert lib.assertMsg (
  caskCount "clash-verge-rev" == 1
) "macbook must retain its existing single Homebrew cask owner";

assert lib.assertMsg (
  nixbox.system.stateVersion == "26.05"
  && nixboxHome.home.stateVersion == "26.05"
  && server.system.stateVersion == "26.05"
  && serverHome.home.stateVersion == "26.05"
) "Clash maintenance must not change established NixOS or Home Manager state versions";
assert lib.assertMsg (
  nixbox.services.tailscale.enable
  && nixbox.services.tailscale.useRoutingFeatures == "none"
  && nixbox.services.tailscale.extraUpFlags == [ ]
  && nixbox.services.tailscale.extraDaemonFlags == [ ]
  && nixbox.services.tailscale.extraSetFlags == [ "--hostname=nixbox" ]
) "Clash maintenance must preserve the established Tailscale declaration";
assert lib.assertMsg (
  nixbox.services.openssh.enable
  && nixbox.services.openssh.settings.PasswordAuthentication == false
  && nixbox.services.openssh.settings.KbdInteractiveAuthentication == false
  && nixbox.services.openssh.settings.PermitRootLogin == "no"
  && nixbox.services.openssh.ports == [ 22 ]
) "Clash maintenance must preserve native key-only OpenSSH";
assert lib.assertMsg (
  nixbox.networking.firewall.checkReversePath
  &&
    sortedPorts nixbox.networking.firewall.allowedTCPPorts == [
      22
      53317
    ]
  &&
    sortedPorts nixbox.networking.firewall.allowedUDPPorts == [
      5353
      41641
      53317
    ]
  && nixbox.networking.firewall.trustedInterfaces == [ "lo" ]
  && !(nixbox.boot.kernel.sysctl ? "net.ipv4.conf.all.forwarding")
  && !(nixbox.boot.kernel.sysctl ? "net.ipv6.conf.all.forwarding")
) "Clash maintenance must not widen firewall trust or packet forwarding";
pkgs.runCommand "clash-verge-rev-policy"
  {
    nativeBuildInputs = [ pkgs.gnugrep ];
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
      '../../modules/capabilities/clash-verge-rev/darwin.nix'
    count_import ${source}/hosts/nixbox/default.nix \
      '../../modules/capabilities/clash-verge-rev/nixos.nix'

    if grep -F -q 'clash-verge-rev' ${source}/hosts/server/default.nix; then
      printf 'server must not import clash-verge-rev\n' >&2
      exit 1
    fi

    grep -Fqx '  version = "2.5.2";' \
      ${packageSource}/pkgs/by-name/cl/clash-verge-rev/package.nix
    grep -Fqx '  version = "2.3.3";' \
      ${packageSource}/pkgs/by-name/cl/clash-verge-rev/service.nix
    grep -Fq '/run/clash-verge-rev/service.sock' \
      ${packageSource}/pkgs/by-name/cl/clash-verge-rev/patch-service-directory.patch
    grep -Fq 'Permissions::from_mode(0o660)' \
      ${packageSource}/pkgs/by-name/cl/clash-verge-rev/patch-service-directory.patch

    test -x ${clashPackage}/bin/clash-verge
    test -x ${clashPackage}/bin/clash-verge-service
    test -x ${clashPackage}/bin/verge-mihomo

    touch "$out"
  ''
