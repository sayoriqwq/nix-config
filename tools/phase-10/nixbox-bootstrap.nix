{
  phase10Preflight,
  pkgs,
  serverConfiguration,
  username,
}:

let
  inherit (pkgs) lib;
  serverConfig = serverConfiguration.config;
  serverNetwork = serverConfig.systemd.network.networks."10-contabo-uplink";
  expectedAddresses = map (address: address.Address) serverNetwork.addresses;
  expectedIPv4Address = lib.findFirst (
    address: lib.hasInfix "." address
  ) (throw "phase10-nixbox-bootstrap: production IPv4 address is missing") expectedAddresses;
  expectedHost = builtins.head (lib.splitString "/" expectedIPv4Address);

  deployKeys = lib.filter (
    key: lib.hasSuffix " nixbox-server-deploy-2026-07-30" key
  ) serverConfig.users.users.${username}.openssh.authorizedKeys.keys;
  deployKey =
    if builtins.length deployKeys == 1 then
      builtins.head deployKeys
    else
      throw "phase10-nixbox-bootstrap: expected exactly one nixbox deploy public key";

  rootKeys = serverConfig.users.users.root.openssh.authorizedKeys.keys;
  macbookKey =
    if builtins.length rootKeys == 1 then
      builtins.head rootKeys
    else
      throw "phase10-nixbox-bootstrap: expected exactly one final root public key";

  remoteAction = pkgs.writeText "phase10-remote-nixbox-bootstrap.sh" (
    builtins.readFile ./remote-nixbox-bootstrap.sh
  );

  makeAction =
    {
      action,
      name,
    }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [
        pkgs.coreutils
        pkgs.gitMinimal
      ];
      text = ''
        fail() {
          printf 'phase10-nixbox-bootstrap: %s\n' "$*" >&2
          exit 1
        }

        if test "$#" -ne 0; then
          fail "accepts no target or extra arguments"
        fi

        if test "$(uname -s)" != "Darwin"; then
          fail "the current bootstrap entry must run on macbook"
        fi

        ${phase10Preflight}/bin/phase10-preflight

        repo_root="$(git rev-parse --show-toplevel)"
        commit="$(git -C "$repo_root" rev-parse HEAD)"
        target="sayori"
        expected_host=${lib.escapeShellArg expectedHost}
        ssh_binary="/usr/bin/ssh"
        ssh_options=(
          -T
          -o BatchMode=yes
          -o ClearAllForwardings=yes
          -o ConnectTimeout=8
          -o ControlMaster=no
          -o ControlPath=none
          -o "HostName=$expected_host"
          -o IdentitiesOnly=yes
          -o ProxyCommand=none
          -o ProxyJump=none
          -o ServerAliveCountMax=2
          -o ServerAliveInterval=5
          -o StrictHostKeyChecking=yes
          -l root
          -p 22
        )

        printf 'phase10-nixbox-bootstrap: local commit=%s action=%s target-alias=%s host=%s user=root strict-host-key=yes\n' \
          "$commit" ${lib.escapeShellArg action} "$target" "$expected_host"

        "$ssh_binary" "''${ssh_options[@]}" "$target" bash -s -- \
          ${lib.escapeShellArg action} \
          ${lib.escapeShellArg deployKey} \
          ${lib.escapeShellArg macbookKey} \
          < ${remoteAction}
      '';
    };
in
{
  add = makeAction {
    action = "add";
    name = "phase10-bootstrap-nixbox";
  };
  remove = makeAction {
    action = "remove";
    name = "phase10-rollback-nixbox-bootstrap";
  };
}
