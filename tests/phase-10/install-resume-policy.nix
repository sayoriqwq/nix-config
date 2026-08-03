{
  nixosAnywhere,
  phase10InstallResume,
  pkgs,
}:

let
  data = phase10InstallResume.testData;
  runtimeInputTest = pkgs.writeShellScript "phase10-install-resume-runtime-input-test" ''
    set -euo pipefail

    fail() {
      printf 'phase10-install-resume-runtime-input-test: %s\n' "$*" >&2
      exit 1
    }

    ${data.runtimeInputFunctions}

    export HOME="$TMPDIR/home"
    ssh_dir="$HOME/.ssh"
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"

    ssh-keygen -q -t ed25519 -N "" -C phase10-runtime-test -f "$ssh_dir/deploy"
    expected_deploy_payload="$(awk 'NF >= 2 { print $1 " " $2; exit }' "$ssh_dir/deploy.pub")"

    ssh-keygen -q -t ed25519 -N "" -C phase10-host-test -f "$TMPDIR/host"
    expected_host="phase10.invalid"
    awk -v host="$expected_host" 'NF >= 2 { print host, $1, $2; exit }' \
      "$TMPDIR/host.pub" > "$ssh_dir/phase10-known-hosts"
    chmod 600 "$ssh_dir/phase10-known-hosts"

    phase10_find_runtime_inputs
    test "$identity_file" = "$ssh_dir/deploy"
    test "$known_hosts_file" = "$ssh_dir/phase10-known-hosts"

    cp "$ssh_dir/deploy" "$ssh_dir/duplicate"
    cp "$ssh_dir/deploy.pub" "$ssh_dir/duplicate.pub"
    chmod 600 "$ssh_dir/duplicate"
    if (phase10_find_runtime_inputs >/dev/null 2>&1); then
      fail "duplicate deploy identities must be rejected"
    fi
    rm "$ssh_dir/duplicate" "$ssh_dir/duplicate.pub"

    chmod 644 "$ssh_dir/phase10-known-hosts"
    if (phase10_find_runtime_inputs >/dev/null 2>&1); then
      fail "unsafe known-hosts mode must be rejected"
    fi
  '';

  preflightSimulation = pkgs.writeShellScript "phase10-install-resume-preflight-simulation" ''
    set -euo pipefail

    accept_fixture() {
      local id="$1"
      local variant="$2"
      local disk_count="$3"
      local disk_size="$4"
      local partition_table="$5"
      local partition_count="$6"
      local boot_matches="$7"
      local root_matches="$8"
      local root_fs="$9"
      local root_rw="''${10}"
      local boot_mounts="''${11}"
      local partial_store="''${12}"
      local install_artifacts="''${13}"
      local target_host_keys="''${14}"
      local source_host_keys="''${15}"

      [[ "$id" == nixos && "$variant" == installer ]] || return 1
      [[ "$disk_count" == 1 && "$disk_size" == ${data.expectedDiskSize} ]] || return 1
      [[ "$partition_table" == gpt && "$partition_count" == 2 ]] || return 1
      [[ "$boot_matches" == yes ]] || return 1
      [[ "$root_matches" == yes && "$root_fs" == ext4 && "$root_rw" == yes ]] || return 1
      [[ "$boot_mounts" == 0 && "$partial_store" == yes ]] || return 1
      [[ "$install_artifacts" == 0 && "$target_host_keys" == 0 ]] || return 1
      (( source_host_keys > 0 )) || return 1
    }

    accept_fixture nixos installer 1 ${data.expectedDiskSize} gpt 2 yes yes ext4 yes 0 yes 0 0 2

    for failed_case in \
      "ubuntu server 1 ${data.expectedDiskSize} gpt 2 yes yes ext4 yes 0 yes 0 0 2" \
      "nixos regular 1 ${data.expectedDiskSize} gpt 2 yes yes ext4 yes 0 yes 0 0 2" \
      "nixos installer 2 ${data.expectedDiskSize} gpt 2 yes yes ext4 yes 0 yes 0 0 2" \
      "nixos installer 1 80530636801 gpt 2 yes yes ext4 yes 0 yes 0 0 2" \
      "nixos installer 1 ${data.expectedDiskSize} dos 2 yes yes ext4 yes 0 yes 0 0 2" \
      "nixos installer 1 ${data.expectedDiskSize} gpt 1 yes yes ext4 yes 0 yes 0 0 2" \
      "nixos installer 1 ${data.expectedDiskSize} gpt 2 no yes ext4 yes 0 yes 0 0 2" \
      "nixos installer 1 ${data.expectedDiskSize} gpt 2 yes no ext4 yes 0 yes 0 0 2" \
      "nixos installer 1 ${data.expectedDiskSize} gpt 2 yes yes ext4 yes 1 yes 0 0 2" \
      "nixos installer 1 ${data.expectedDiskSize} gpt 2 yes yes ext4 yes 0 no 0 0 2" \
      "nixos installer 1 ${data.expectedDiskSize} gpt 2 yes yes ext4 yes 0 yes 1 0 2" \
      "nixos installer 1 ${data.expectedDiskSize} gpt 2 yes yes ext4 yes 0 yes 0 1 2" \
      "nixos installer 1 ${data.expectedDiskSize} gpt 2 yes yes ext4 yes 0 yes 0 0 0"
    do
      # shellcheck disable=SC2086
      if accept_fixture $failed_case; then
        echo "phase10-install-resume-policy: fail-closed fixture was accepted: $failed_case" >&2
        exit 1
      fi
    done
  '';
in
pkgs.runCommand "phase10-install-resume-policy"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.openssh
      pkgs.shellcheck
      pkgs.util-linux
    ];
  }
  ''
    upstream=${nixosAnywhere}/libexec/nixos-anywhere/nixos-anywhere.sh
    install=${phase10InstallResume.install}/bin/phase10-install-resume
    plan=${phase10InstallResume.plan}/bin/phase10-install-resume-plan
    preflight=${data.remotePreflight}

    grep -F 'declare -a sshArgs=("-o" "IdentitiesOnly=yes" "-i" "$tempDir/nixos-anywhere")' "$upstream"
    if grep -F 'UserKnownHostsFile=/dev/null' "$upstream"; then
      echo "phase10-install-resume-policy: strict variant still discards known hosts" >&2
      exit 1
    fi
    if grep -F 'StrictHostKeyChecking=no' "$upstream"; then
      echo "phase10-install-resume-policy: strict variant still disables host checking" >&2
      exit 1
    fi
    grep -F 'phase10 resume variant permits only install,reboot' "$upstream"
    if grep -F '    sleep 3' "$upstream"; then
      echo "phase10-install-resume-policy: upstream identity upload still retries forever" >&2
      exit 1
    fi
    grep -F 'for attempt in {1..12}' "$upstream"
    grep -F 'machine remained reachable after the bounded reboot wait' "$upstream"
    grep -F -- '-o ConnectTimeout=20' "$upstream"

    grep -F -- '--no-substitute-on-destination' "$install"
    grep -F -- '--no-use-machine-substituters' "$install"
    grep -F -- '--copy-host-keys' "$install"
    grep -F -- '--phases "install,reboot"' "$install"
    grep -F -- 'StrictHostKeyChecking=yes' "$install"
    grep -F -- 'UserKnownHostsFile=$known_hosts_file' "$install"
    grep -F -- 'ConnectionAttempts=3' "$install"
    grep -F -- 'ConnectTimeout=20' "$install"
    grep -F -- 'ServerAliveInterval=15' "$install"
    grep -F -- 'ServerAliveCountMax=20' "$install"
    grep -F ${data.recoveryRevision} "$install"
    grep -F ${data.expectedDrv} "$install"
    grep -F ${data.expectedSystem} "$install"
    test ${data.expectedBootPartition} = /dev/disk/by-partlabel/gpt-main-boot
    test ${data.expectedRootPartition} = /dev/disk/by-partlabel/gpt-main-root
    grep -F /dev/disk/by-partlabel/gpt-main-boot "$install"
    grep -F /dev/disk/by-partlabel/gpt-main-root "$install"
    grep -F 'type RESUME' "$install"

    if grep -F -- '--kexec' "$install" || grep -F 'kexec,disko' "$install"; then
      echo "phase10-install-resume-policy: forbidden destructive phase leaked into resume helper" >&2
      exit 1
    fi
    if grep -F '/home/sayori/.ssh' "$install"; then
      echo "phase10-install-resume-policy: a private runtime path was embedded" >&2
      exit 1
    fi

    if "$plan" unexpected >plan.log 2>&1; then
      echo "phase10-install-resume-policy: plan accepted an extra argument" >&2
      exit 1
    fi
    grep -F 'accepts no target or extra arguments' plan.log

    if "$install" unexpected >install-arg.log 2>&1; then
      echo "phase10-install-resume-policy: install accepted an extra argument" >&2
      exit 1
    fi
    grep -F 'accepts no target or extra arguments' install-arg.log

    if "$install" </dev/null >install-tty.log 2>&1; then
      echo "phase10-install-resume-policy: install accepted a non-TTY invocation" >&2
      exit 1
    fi
    grep -F 'requires a live interactive nixbox terminal' install-tty.log

    shellcheck "$preflight" ${runtimeInputTest} ${preflightSimulation}
    grep -F '(( EUID != 0 ))' "$preflight"
    grep -F '"''${ID:-}" != "nixos" || "''${VARIANT_ID:-}" != "installer"' "$preflight"
    grep -F '[[ "$disk_size_bytes" == "$expected_disk_size" ]]' "$preflight"
    grep -F '[[ "$disk_partition_table" == "gpt" ]]' "$preflight"
    grep -F '[[ "$partition_count" == "2" ]]' "$preflight"
    grep -F '21686148-6449-6e6f-744e-656564454649' "$preflight"
    grep -F '0fc63daf-8483-4772-8e79-3d69d8477de4' "$preflight"
    grep -F 'findmnt -rn -M /mnt/boot' "$preflight"
    grep -F '[[ -d /mnt/nix/store ]]' "$preflight"
    grep -F '[[ ! -e /mnt/nix/var/nix/profiles/system && ! -L /mnt/nix/var/nix/profiles/system ]]' "$preflight"
    grep -F '[[ ! -e /mnt/boot/grub/grub.cfg ]]' "$preflight"
    grep -F '[[ ! -e /mnt/etc/NIXOS ]]' "$preflight"
    grep -F -- "-name 'ssh_host_*_key' -size +0c" "$preflight"
    grep -F '(( source_host_key_count > 0 ))' "$preflight"
    grep -F 'source-host-private-keys=%s' "$preflight"
    grep -F '[[ "$actual_dns_csv" == "$expected_dns_csv" ]]' "$preflight"

    ${runtimeInputTest}
    ${preflightSimulation}

    touch "$out"
  ''
