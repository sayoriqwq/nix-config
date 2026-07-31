{
  pkgs,
  serverConfiguration,
}:

let
  inherit (pkgs) lib;
  serverConfig = serverConfiguration.config;
  serverNetwork = serverConfig.systemd.network.networks."10-contabo-uplink";
  expectedAddresses = map (address: address.Address) serverNetwork.addresses;
  expectedRoutes = serverNetwork.routes;

  expectedDisk = serverConfig.disko.devices.disk.main.device;
  expectedIPv4Address = lib.findFirst (
    address: lib.hasInfix "." address
  ) (throw "phase10-preflight: production IPv4 address is missing") expectedAddresses;
  expectedIPv6Address = lib.findFirst (
    address: lib.hasInfix ":" address
  ) (throw "phase10-preflight: production IPv6 address is missing") expectedAddresses;
  expectedIPv4Gateway =
    (lib.findFirst (
      route: lib.hasInfix "." route.Gateway
    ) (throw "phase10-preflight: production IPv4 gateway is missing") expectedRoutes).Gateway;
  expectedIPv6Gateway =
    (lib.findFirst (
      route: lib.hasInfix ":" route.Gateway
    ) (throw "phase10-preflight: production IPv6 gateway is missing") expectedRoutes).Gateway;
  expectedDnsCsv = lib.concatStringsSep "," serverNetwork.networkConfig.DNS;
  expectedHost = builtins.head (lib.splitString "/" expectedIPv4Address);

  remotePreflight = pkgs.writeText "phase10-remote-preflight.sh" (
    builtins.readFile ./remote-preflight.sh
  );
in
pkgs.writeShellApplication {
  name = "phase10-preflight";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.gawk
    pkgs.gitMinimal
    pkgs.gnugrep
    pkgs.openssh
  ];
  text = ''
    fail() {
      printf 'phase10-preflight: %s\n' "$*" >&2
      exit 1
    }

    if test "$#" -ne 0; then
      fail "accepts no target or extra arguments"
    fi

    if test "$(uname -s)" != "Darwin"; then
      fail "the current preflight entry must run on macbook"
    fi

    repo_root="$(git rev-parse --show-toplevel)"
    if test -n "$(git -C "$repo_root" status --porcelain)"; then
      fail "requires a clean checkout so the inspected revision is auditable"
    fi

    target="sayori"
    expected_host=${lib.escapeShellArg expectedHost}
    expected_user="root"
    expected_port="22"
    expected_route_interface="en0"

    ssh_config="$(ssh -G "$target" 2>/dev/null)"
    resolved_host="$(awk '$1 == "hostname" { print $2; exit }' <<<"$ssh_config")"
    resolved_user="$(awk '$1 == "user" { print $2; exit }' <<<"$ssh_config")"
    resolved_port="$(awk '$1 == "port" { print $2; exit }' <<<"$ssh_config")"
    proxy_command="$(awk '$1 == "proxycommand" { print $2; exit }' <<<"$ssh_config")"
    proxy_jump="$(awk '$1 == "proxyjump" { print $2; exit }' <<<"$ssh_config")"

    test "$resolved_host" = "$expected_host" ||
      fail "SSH alias target drift: expected $expected_host, found $resolved_host"
    test "$resolved_user" = "$expected_user" ||
      fail "SSH alias user drift: expected $expected_user, found $resolved_user"
    test "$resolved_port" = "$expected_port" ||
      fail "SSH alias port drift: expected $expected_port, found $resolved_port"
    case "$proxy_command" in
      "" | none) ;;
      *) fail "SSH ProxyCommand is not allowed for the independent macbook path" ;;
    esac
    case "$proxy_jump" in
      "" | none) ;;
      *) fail "SSH ProxyJump is not allowed for the independent macbook path" ;;
    esac

    route_interface="$(
      /sbin/route -n get "$expected_host" |
        awk '$1 == "interface:" { print $2; exit }'
    )"
    test "$route_interface" = "$expected_route_interface" ||
      fail "direct-route drift: expected $expected_route_interface, found $route_interface"

    ssh_options=(
      -o BatchMode=yes
      -o ConnectTimeout=8
      -o IdentitiesOnly=yes
      -o ServerAliveCountMax=2
      -o ServerAliveInterval=5
      -o StrictHostKeyChecking=yes
    )

    commit="$(git -C "$repo_root" rev-parse HEAD)"
    printf 'phase10-preflight: local commit=%s target-alias=%s host=%s user=%s route-interface=%s strict-host-key=yes\n' \
      "$commit" "$target" "$expected_host" "$expected_user" "$route_interface"

    ssh "''${ssh_options[@]}" "$target" bash -s -- \
      ${lib.escapeShellArg expectedDisk} \
      ${lib.escapeShellArg expectedIPv4Address} \
      ${lib.escapeShellArg expectedIPv4Gateway} \
      ${lib.escapeShellArg expectedIPv6Address} \
      ${lib.escapeShellArg expectedIPv6Gateway} \
      ${lib.escapeShellArg expectedDnsCsv} \
      x86_64 \
      virtio_net \
      < ${remotePreflight}

    printf 'phase10-preflight: PASS; production was inspected read-only and no remote file was created\n'
  '';
}
