{
  nixosAnywhere,
  phase10Install,
  pkgs,
}:

let
  runtimeInputTest = pkgs.writeShellScript "phase10-install-runtime-input-test" ''
    set -euo pipefail

    fail() {
      printf 'phase10-install-runtime-input-test: %s\n' "$*" >&2
      exit 1
    }

    ${phase10Install.testData.runtimeInputFunctions}

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
    chmod 600 "$ssh_dir/phase10-known-hosts"

    printf 'other.invalid ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestOnlyNotARealKey\n' \
      >> "$ssh_dir/phase10-known-hosts"
    if (phase10_find_runtime_inputs >/dev/null 2>&1); then
      fail "a non-dedicated known-hosts file must be rejected"
    fi
  '';
in
pkgs.runCommand "phase10-install-policy"
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

    grep -F 'declare -a sshArgs=("-o" "IdentitiesOnly=yes" "-i" "$tempDir/nixos-anywhere")' "$upstream"
    if grep -F 'UserKnownHostsFile=/dev/null' "$upstream"; then
      echo "phase10-install-policy: patched nixos-anywhere still discards known hosts" >&2
      exit 1
    fi
    if grep -F 'StrictHostKeyChecking=no' "$upstream"; then
      echo "phase10-install-policy: patched nixos-anywhere still disables host checking" >&2
      exit 1
    fi

    grep -R -F -- '--no-substitute-on-destination' ${phase10Install.install}
    grep -R -F -- '--copy-host-keys' ${phase10Install.install}
    grep -R -F -- 'StrictHostKeyChecking=yes' ${phase10Install.install}
    grep -R -F -- 'UserKnownHostsFile=$known_hosts_file' ${phase10Install.install}
    grep -R -F -- '--phases kexec,disko,install,reboot' ${phase10Install.install}

    if ${phase10Install.plan}/bin/phase10-install-plan unexpected >plan.log 2>&1; then
      echo "phase10-install-policy: plan accepted an extra argument" >&2
      exit 1
    fi
    grep -F 'accepts no target or extra arguments' plan.log

    if ${phase10Install.install}/bin/phase10-install unexpected >install.log 2>&1; then
      echo "phase10-install-policy: install accepted an extra argument" >&2
      exit 1
    fi
    grep -F 'accepts no target or extra arguments' install.log

    shellcheck ${runtimeInputTest}
    ${runtimeInputTest}

    touch "$out"
  ''
