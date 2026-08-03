{
  kexecInstaller,
  nixosAnywhere,
  pkgs,
  serverConfiguration,
  sourceRevision,
  username,
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
  ) (throw "phase10-install: production IPv4 address is missing") expectedAddresses;
  expectedIPv6Address = lib.findFirst (
    address: lib.hasInfix ":" address
  ) (throw "phase10-install: production IPv6 address is missing") expectedAddresses;
  expectedIPv4Gateway =
    (lib.findFirst (
      route: lib.hasInfix "." route.Gateway
    ) (throw "phase10-install: production IPv4 gateway is missing") expectedRoutes).Gateway;
  expectedIPv6Gateway =
    (lib.findFirst (
      route: lib.hasInfix ":" route.Gateway
    ) (throw "phase10-install: production IPv6 gateway is missing") expectedRoutes).Gateway;
  expectedDnsCsv = lib.concatStringsSep "," serverNetwork.networkConfig.DNS;
  expectedHost = builtins.head (lib.splitString "/" expectedIPv4Address);

  deployKeys = lib.filter (
    key: lib.hasSuffix " nixbox-server-deploy-2026-07-30" key
  ) serverConfig.users.users.${username}.openssh.authorizedKeys.keys;
  deployKey =
    if builtins.length deployKeys == 1 then
      builtins.head deployKeys
    else
      throw "phase10-install: expected exactly one nixbox deploy public key";
  deployKeyFields = lib.splitString " " deployKey;
  deployKeyPayload = lib.concatStringsSep " " (lib.take 2 deployKeyFields);

  kexecTarball = "${kexecInstaller}/nixos-kexec-installer-noninteractive-x86_64-linux.tar.gz";
  nixosAnywhereBinary = "${nixosAnywhere}/bin/nixos-anywhere";
  remotePreflight = pkgs.writeText "phase10-install-remote-preflight.sh" (
    builtins.readFile ./remote-preflight.sh
  );

  runtimeInputFunctions = ''
    phase10_require_private_file() {
      local path="$1"
      local label="$2"

      if test ! -f "$path" || test -L "$path"; then
        fail "$label must be one regular, non-symlink file"
      fi
      test "$(stat -c '%u' "$path")" = "$(id -u)" ||
        fail "$label must be owned by the current nixbox user"
      test "$(stat -c '%a' "$path")" = "600" ||
        fail "$label must have mode 0600"
    }

    phase10_find_runtime_inputs() {
      local ssh_dir="$HOME/.ssh"
      local public_path public_payload private_path actual_payload
      local candidate matched_count total_count
      local -a identity_candidates=()
      local -a known_hosts_candidates=()

      if test ! -d "$ssh_dir" || test -L "$ssh_dir"; then
        fail "nixbox SSH directory must be one real directory"
      fi
      test "$(stat -c '%u' "$ssh_dir")" = "$(id -u)" ||
        fail "nixbox SSH directory must be owned by the current user"
      test "$(stat -c '%a' "$ssh_dir")" = "700" ||
        fail "nixbox SSH directory must have mode 0700"

      while IFS= read -r -d "" public_path; do
        test ! -L "$public_path" || continue
        test "$(stat -c '%u' "$public_path")" = "$(id -u)" || continue
        public_payload="$(awk 'NF >= 2 { print $1 " " $2; exit }' "$public_path")"
        test "$public_payload" = "$expected_deploy_payload" || continue

        private_path="''${public_path%.pub}"
        phase10_require_private_file "$private_path" "dedicated deploy identity"
        if ! actual_payload="$({
          timeout 5 setsid --wait ssh-keygen -y -f "$private_path" </dev/null 2>/dev/null
        } | awk 'NF >= 2 { print $1 " " $2; exit }')"; then
          fail "dedicated deploy identity must be unencrypted and readable without prompting"
        fi
        test "$actual_payload" = "$expected_deploy_payload" ||
          fail "dedicated deploy identity does not match its reviewed public key"
        identity_candidates+=("$private_path")
      done < <(find "$ssh_dir" -maxdepth 2 -type f -name '*.pub' -print0)

      test "''${#identity_candidates[@]}" -eq 1 ||
        fail "expected exactly one local private identity matching the reviewed deploy public key"
      identity_file="''${identity_candidates[0]}"

      while IFS= read -r -d "" candidate; do
        test ! -L "$candidate" || continue
        matched_count="$({
          ssh-keygen -F "$expected_host" -f "$candidate" 2>/dev/null || true
        } | awk '$1 !~ /^#/ && NF { count++ } END { print count + 0 }')"
        test "$matched_count" -gt 0 || continue

        phase10_require_private_file "$candidate" "dedicated known-hosts file"
        total_count="$(awk 'NF && $1 !~ /^#/ { count++ } END { print count + 0 }' "$candidate")"
        test "$matched_count" -eq "$total_count" ||
          fail "dedicated known-hosts file must contain only the reviewed production host"
        known_hosts_candidates+=("$candidate")
      done < <(
        find "$ssh_dir" -maxdepth 2 -type f \
          \( -name '*known_hosts*' -o -name '*known-hosts*' \) -print0
      )

      test "''${#known_hosts_candidates[@]}" -eq 1 ||
        fail "expected exactly one dedicated known-hosts file for the reviewed production host"
      known_hosts_file="''${known_hosts_candidates[0]}"

      if printf '%s\n' "$identity_file" "$known_hosts_file" | grep -q '[[:space:]]'; then
        fail "private SSH input paths must not contain whitespace"
      fi
    }
  '';

  commonFunctions = ''
    fail() {
      printf 'phase10-install: %s\n' "$*" >&2
      exit 1
    }

    phase10_prepare_local() {
      if test "$(uname -s)" != "Linux" || test "$(uname -m)" != "x86_64"; then
        fail "must run on the x86_64-linux nixbox"
      fi
      test "$(id -un)" = ${lib.escapeShellArg username} ||
        fail "must run as the reviewed nixbox user"

      repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" ||
        fail "must run from the reviewed nix-config checkout"
      test -z "$(git -C "$repo_root" status --porcelain=v1 --untracked-files=normal)" ||
        fail "requires a clean checkout so commit and closure are auditable"
      commit="$(git -C "$repo_root" rev-parse --verify 'HEAD^{commit}')"
      source_revision=${lib.escapeShellArg (if sourceRevision == null then "" else sourceRevision)}
      test -n "$source_revision" ||
        fail "entry must be built from a committed Git flake, not an unfrozen path input"
      test "$commit" = "$source_revision" ||
        fail "entry revision does not match the current checkout; rebuild it from this commit"

      expected_host=${lib.escapeShellArg expectedHost}
      expected_disk=${lib.escapeShellArg expectedDisk}
      expected_deploy_payload=${lib.escapeShellArg deployKeyPayload}
      flake_base="git+file://$repo_root?rev=$commit"
      flake_ref="$flake_base#server"
      nixos_anywhere_binary=${lib.escapeShellArg nixosAnywhereBinary}
      kexec_tarball=${lib.escapeShellArg kexecTarball}

      phase10_find_runtime_inputs

      drv_path="$(
        nix eval --raw \
          "$flake_base#nixosConfigurations.server.config.system.build.toplevel.drvPath"
      )"
      system_path="$(
        nix build --no-link --print-out-paths --option builders "" \
          "$flake_base#nixosConfigurations.server.config.system.build.toplevel"
      )"
      disko_path="$(
        nix build --no-link --print-out-paths --option builders "" \
          "$flake_base#nixosConfigurations.server.config.system.build.diskoScript"
      )"

      test -e "$kexec_tarball" || fail "the pinned local kexec tarball is unavailable"
      test -e "$system_path" || fail "the frozen server system closure was not realised"
      test -e "$disko_path" || fail "the frozen disko script was not realised"
    }

    phase10_print_plan() {
      printf '%s\n' \
        "phase10-install-plan: production-contact=no" \
        "phase10-install-plan: commit=$commit" \
        "phase10-install-plan: target=root@$expected_host port=22" \
        "phase10-install-plan: stable-disk=$expected_disk" \
        "phase10-install-plan: flake=$flake_ref" \
        "phase10-install-plan: server-drv=$drv_path" \
        "phase10-install-plan: server-system=$system_path" \
        "phase10-install-plan: disko-script=$disko_path" \
        "phase10-install-plan: kexec-tarball=$kexec_tarball" \
        "phase10-install-plan: local-private-inputs=PASS (paths redacted)" \
        "phase10-install-plan: phases=kexec,disko,install,reboot" \
        "phase10-install-plan: full command follows; private paths are runtime variables and are never printed"

      printf '%q ' "$nixos_anywhere_binary"
      printf '%q ' \
        --flake "$flake_ref" \
        --build-on local \
        --option builders "" \
        --no-substitute-on-destination \
        --no-use-machine-substituters \
        --copy-host-keys \
        --kexec "$kexec_tarball" \
        --phases kexec,disko,install,reboot \
        --ssh-port 22
      printf '%s ' "-i \"\$phase10_private_identity\""
      for option in \
        BatchMode=yes \
        CheckHostIP=yes \
        ClearAllForwardings=yes \
        ConnectTimeout=8 \
        ControlMaster=no \
        ControlPath=none \
        ControlPersist=no \
        GlobalKnownHostsFile=/dev/null \
        IdentityAgent=none \
        KbdInteractiveAuthentication=no \
        KnownHostsCommand=none \
        PasswordAuthentication=no \
        PreferredAuthentications=publickey \
        ProxyCommand=none \
        ProxyJump=none \
        ServerAliveCountMax=12 \
        ServerAliveInterval=5 \
        StrictHostKeyChecking=yes \
        UpdateHostKeys=no \
        VerifyHostKeyDNS=no
      do
        printf '%q ' --ssh-option "$option"
      done
      printf '%s ' "--ssh-option \"UserKnownHostsFile=\$phase10_private_known_hosts\""
      printf '%q %q\n' --target-host "root@$expected_host"
    }

    ${runtimeInputFunctions}
  '';

  runtimeInputs = [
    pkgs.coreutils
    pkgs.findutils
    pkgs.gawk
    pkgs.gitMinimal
    pkgs.gnugrep
    pkgs.nix
    pkgs.openssh
    pkgs.util-linux
  ];

  plan = pkgs.writeShellApplication {
    name = "phase10-install-plan";
    inherit runtimeInputs;
    text = ''
      if test "$#" -ne 0; then
        printf 'phase10-install: accepts no target or extra arguments\n' >&2
        exit 1
      fi

      ${commonFunctions}
      phase10_prepare_local
      phase10_print_plan
      printf 'phase10-install-plan: PASS; no SSH connection or production change was attempted\n'
    '';
  };

  install = pkgs.writeShellApplication {
    name = "phase10-install";
    inherit runtimeInputs;
    text = ''
      if test "$#" -ne 0; then
        printf 'phase10-install: accepts no target or extra arguments\n' >&2
        exit 1
      fi

      ${commonFunctions}
      test -t 0 && test -t 1 ||
        fail "requires a live interactive nixbox terminal"

      phase10_prepare_local
      phase10_print_plan

      printf 'phase10-install: type INSTALL to confirm the already-approved destructive action: ' >/dev/tty
      IFS= read -r confirmation </dev/tty
      test "$confirmation" = "INSTALL" || fail "interactive confirmation did not match; nothing contacted"

      ssh_options=(
        -T
        -i "$identity_file"
        -o BatchMode=yes
        -o CheckHostIP=yes
        -o ClearAllForwardings=yes
        -o ConnectTimeout=8
        -o ControlMaster=no
        -o ControlPath=none
        -o ControlPersist=no
        -o GlobalKnownHostsFile=/dev/null
        -o IdentityAgent=none
        -o KbdInteractiveAuthentication=no
        -o KnownHostsCommand=none
        -o PasswordAuthentication=no
        -o PreferredAuthentications=publickey
        -o ProxyCommand=none
        -o ProxyJump=none
        -o ServerAliveCountMax=2
        -o ServerAliveInterval=5
        -o StrictHostKeyChecking=yes
        -o UpdateHostKeys=no
        -o "UserKnownHostsFile=$known_hosts_file"
        -o VerifyHostKeyDNS=no
        -l root
        -p 22
      )

      printf 'phase10-install: running the final read-only production preflight before kexec\n'
      ${pkgs.openssh}/bin/ssh "''${ssh_options[@]}" "$expected_host" bash -s -- \
        ${lib.escapeShellArg expectedDisk} \
        ${lib.escapeShellArg expectedIPv4Address} \
        ${lib.escapeShellArg expectedIPv4Gateway} \
        ${lib.escapeShellArg expectedIPv6Address} \
        ${lib.escapeShellArg expectedIPv6Gateway} \
        ${lib.escapeShellArg expectedDnsCsv} \
        x86_64 \
        virtio_net \
        < ${remotePreflight}

      anywhere_args=(
        --flake "$flake_ref"
        --build-on local
        --option builders ""
        --no-substitute-on-destination
        --no-use-machine-substituters
        --copy-host-keys
        --kexec "$kexec_tarball"
        --phases "kexec,disko,install,reboot"
        --ssh-port 22
        -i "$identity_file"
      )
      for option in \
        BatchMode=yes \
        CheckHostIP=yes \
        ClearAllForwardings=yes \
        ConnectTimeout=8 \
        ControlMaster=no \
        ControlPath=none \
        ControlPersist=no \
        GlobalKnownHostsFile=/dev/null \
        IdentityAgent=none \
        KbdInteractiveAuthentication=no \
        KnownHostsCommand=none \
        PasswordAuthentication=no \
        PreferredAuthentications=publickey \
        ProxyCommand=none \
        ProxyJump=none \
        ServerAliveCountMax=12 \
        ServerAliveInterval=5 \
        StrictHostKeyChecking=yes \
        UpdateHostKeys=no \
        VerifyHostKeyDNS=no
      do
        anywhere_args+=(--ssh-option "$option")
      done
      anywhere_args+=(
        --ssh-option "UserKnownHostsFile=$known_hosts_file"
        --target-host "root@$expected_host"
      )

      printf 'phase10-install: preflight PASS; entering the approved kexec/disko/install/reboot sequence\n'
      exec env \
        -u SSH_AGENT_PID \
        -u SSH_ASKPASS \
        -u SSH_AUTH_SOCK \
        -u SSH_PRIVATE_KEY \
        -u SSHPASS \
        "$nixos_anywhere_binary" "''${anywhere_args[@]}"
    '';
  };
in
{
  inherit install plan;
  testData = {
    inherit
      deployKeyPayload
      expectedHost
      runtimeInputFunctions
      ;
  };
}
