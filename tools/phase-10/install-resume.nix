{
  nixosAnywhere,
  pkgs,
  sourceRevision,
  username,
}:

let
  inherit (pkgs) lib;

  recoveryRevision = "0ba710e8a243e5d9c4e3652b08a35ce709cbb629";
  expectedDrv = "/nix/store/wzag8v8iv686cz62qcy6zaxas97c5nhv-nixos-system-server-26.05.20260719.fd14620.drv";
  expectedSystem = "/nix/store/8zy753v5xl4vfrq0ndwvzj3mw0mggyjg-nixos-system-server-26.05.20260719.fd14620";
  expectedHost = "38.242.129.34";
  expectedDisk = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0";
  expectedDiskSize = "80530636800";
  expectedBootPartition = "/dev/disk/by-partlabel/gpt-main-boot";
  expectedRootPartition = "/dev/disk/by-partlabel/gpt-main-root";
  expectedIPv4Address = "38.242.129.34/21";
  expectedIPv4Gateway = "38.242.128.1";
  expectedIPv6Address = "2a02:c207:2301:9930::1/64";
  expectedIPv6Gateway = "fe80::1";
  expectedDnsCsv = "213.136.95.10,213.136.95.11,2a02:c207::1:53";
  deployKeyPayload = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG7pbS2HOp0EvAUj35QLEYNpDPmBtS79qJmyU1KLwqpz";
  nixosAnywhereBinary = "${nixosAnywhere}/bin/nixos-anywhere";
  remotePreflight = pkgs.writeText "phase10-install-resume-remote-preflight.sh" (
    builtins.readFile ./remote-resume-preflight.sh
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

  sshOptionValues = [
    "BatchMode=yes"
    "CheckHostIP=yes"
    "ClearAllForwardings=yes"
    "ConnectionAttempts=3"
    "ConnectTimeout=20"
    "ControlMaster=no"
    "ControlPath=none"
    "ControlPersist=no"
    "GlobalKnownHostsFile=/dev/null"
    "IdentityAgent=none"
    "KbdInteractiveAuthentication=no"
    "KnownHostsCommand=none"
    "PasswordAuthentication=no"
    "PreferredAuthentications=publickey"
    "ProxyCommand=none"
    "ProxyJump=none"
    "ServerAliveCountMax=20"
    "ServerAliveInterval=15"
    "StrictHostKeyChecking=yes"
    "UpdateHostKeys=no"
    "VerifyHostKeyDNS=no"
  ];

  commonFunctions = ''
    fail() {
      printf 'phase10-install-resume: %s\n' "$*" >&2
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
        fail "requires a clean checkout so helper and recovery closure are auditable"
      helper_commit="$(git -C "$repo_root" rev-parse --verify 'HEAD^{commit}')"
      source_revision=${lib.escapeShellArg (if sourceRevision == null then "" else sourceRevision)}
      test -n "$source_revision" ||
        fail "entry must be built from a committed Git flake, not an unfrozen path input"
      test "$helper_commit" = "$source_revision" ||
        fail "entry revision does not match the current checkout; rebuild it from this commit"

      recovery_commit=${lib.escapeShellArg recoveryRevision}
      git -C "$repo_root" cat-file -e "$recovery_commit^{commit}" 2>/dev/null ||
        fail "the approved recovery commit is unavailable in this checkout"

      expected_host=${lib.escapeShellArg expectedHost}
      expected_disk=${lib.escapeShellArg expectedDisk}
      expected_deploy_payload=${lib.escapeShellArg deployKeyPayload}
      recovery_flake_base="git+file://$repo_root?rev=$recovery_commit"
      recovery_flake_ref="$recovery_flake_base#server"
      nixos_anywhere_binary=${lib.escapeShellArg nixosAnywhereBinary}

      phase10_find_runtime_inputs

      drv_path="$(
        nix eval --raw \
          "$recovery_flake_base#nixosConfigurations.server.config.system.build.toplevel.drvPath"
      )"
      test "$drv_path" = ${lib.escapeShellArg expectedDrv} ||
        fail "approved server derivation drifted"

      system_path="$(
        nix build --no-link --print-out-paths --option builders "" \
          "$recovery_flake_base#nixosConfigurations.server.config.system.build.toplevel"
      )"
      test "$system_path" = ${lib.escapeShellArg expectedSystem} ||
        fail "approved server system closure drifted"
      test -e "$system_path" || fail "approved server system closure was not realised"
    }

    phase10_print_plan() {
      printf '%s\n' \
        "phase10-install-resume-plan: production-contact=no" \
        "phase10-install-resume-plan: helper-commit=$helper_commit" \
        "phase10-install-resume-plan: recovery-commit=$recovery_commit" \
        "phase10-install-resume-plan: target=root@$expected_host port=22" \
        "phase10-install-resume-plan: stable-disk=$expected_disk" \
        "phase10-install-resume-plan: flake=$recovery_flake_ref" \
        "phase10-install-resume-plan: server-drv=$drv_path" \
        "phase10-install-resume-plan: server-system=$system_path" \
        "phase10-install-resume-plan: local-private-inputs=PASS (paths redacted)" \
        "phase10-install-resume-plan: phases=install,reboot" \
        "phase10-install-resume-plan: ssh-tolerance=ConnectionAttempts=3 ConnectTimeout=20 ServerAliveInterval=15 ServerAliveCountMax=20" \
        "phase10-install-resume-plan: full command follows; private paths are runtime variables and are never printed"

      printf '%q ' "$nixos_anywhere_binary"
      printf '%q ' \
        --flake "$recovery_flake_ref" \
        --build-on local \
        --option builders "" \
        --no-substitute-on-destination \
        --no-use-machine-substituters \
        --copy-host-keys \
        --phases install,reboot \
        --ssh-port 22
      # The plan intentionally prints redacted runtime variable references.
      # shellcheck disable=SC2016
      printf '%s ' '-i "$phase10_private_identity"'
      for option in ${lib.concatStringsSep " " (map lib.escapeShellArg sshOptionValues)}; do
        printf '%q ' --ssh-option "$option"
      done
      # shellcheck disable=SC2016
      printf '%s ' '--ssh-option "UserKnownHostsFile=$phase10_private_known_hosts"'
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
    name = "phase10-install-resume-plan";
    inherit runtimeInputs;
    text = ''
      if test "$#" -ne 0; then
        printf 'phase10-install-resume: accepts no target or extra arguments\n' >&2
        exit 1
      fi

      ${commonFunctions}
      phase10_prepare_local
      phase10_print_plan
      printf 'phase10-install-resume-plan: PASS; no SSH connection or production change was attempted\n'
    '';
  };

  install = pkgs.writeShellApplication {
    name = "phase10-install-resume";
    inherit runtimeInputs;
    text = ''
      if test "$#" -ne 0; then
        printf 'phase10-install-resume: accepts no target or extra arguments\n' >&2
        exit 1
      fi

      ${commonFunctions}
      test -t 0 && test -t 1 || fail "requires a live interactive nixbox terminal"

      phase10_prepare_local
      phase10_print_plan

      printf 'phase10-install-resume: type RESUME to confirm the separately approved recovery action: ' >/dev/tty
      IFS= read -r confirmation </dev/tty
      test "$confirmation" = "RESUME" || fail "interactive confirmation did not match; nothing contacted"

      ssh_options=(
        -T
        -i "$identity_file"
        ${lib.concatStringsSep "\n        " (
          map (option: "-o ${lib.escapeShellArg option}") sshOptionValues
        )}
        -o "UserKnownHostsFile=$known_hosts_file"
        -l root
        -p 22
      )

      printf 'phase10-install-resume: running the dedicated read-only NixOS installer preflight\n'
      ${pkgs.openssh}/bin/ssh "''${ssh_options[@]}" "$expected_host" bash -s -- \
        ${lib.escapeShellArg expectedDisk} \
        ${lib.escapeShellArg expectedDiskSize} \
        ${lib.escapeShellArg expectedBootPartition} \
        ${lib.escapeShellArg expectedRootPartition} \
        ${lib.escapeShellArg expectedIPv4Address} \
        ${lib.escapeShellArg expectedIPv4Gateway} \
        ${lib.escapeShellArg expectedIPv6Address} \
        ${lib.escapeShellArg expectedIPv6Gateway} \
        ${lib.escapeShellArg expectedDnsCsv} \
        x86_64 \
        virtio_net \
        < ${remotePreflight}

      anywhere_args=(
        --flake "$recovery_flake_ref"
        --build-on local
        --option builders ""
        --no-substitute-on-destination
        --no-use-machine-substituters
        --copy-host-keys
        --phases "install,reboot"
        --ssh-port 22
        -i "$identity_file"
      )
      for option in ${lib.concatStringsSep " " (map lib.escapeShellArg sshOptionValues)}; do
        anywhere_args+=(--ssh-option "$option")
      done
      anywhere_args+=(
        --ssh-option "UserKnownHostsFile=$known_hosts_file"
        --target-host "root@$expected_host"
      )

      printf 'phase10-install-resume: preflight PASS; entering the approved install/reboot recovery sequence\n'
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
      expectedBootPartition
      expectedDisk
      expectedDiskSize
      expectedDrv
      expectedHost
      expectedRootPartition
      expectedSystem
      recoveryRevision
      remotePreflight
      runtimeInputFunctions
      ;
  };
}
