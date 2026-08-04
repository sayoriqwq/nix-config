{
  nixosAnywherePackage,
  pkgs,
}:

pkgs.writeShellApplication {
  name = "server-recovery-test";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.gawk
    pkgs.gitMinimal
    pkgs.nix
    nixosAnywherePackage
  ];
  text = ''
    if test "$#" -ne 0; then
      echo "server-recovery-test accepts no target or extra arguments" >&2
      exit 2
    fi

    repo_root="$(git rev-parse --show-toplevel)"

    if test "$(uname -m)" != "x86_64"; then
      echo "server-recovery-test must run on the x86_64 nixbox" >&2
      exit 1
    fi

    if ! test -r /dev/kvm || ! test -w /dev/kvm; then
      echo "server-recovery-test requires user-accessible /dev/kvm" >&2
      exit 1
    fi

    if test -n "$(git -C "$repo_root" status --porcelain)"; then
      echo "server-recovery-test requires a clean checkout so the tested revision is auditable" >&2
      exit 1
    fi

    free_kib="$(df -Pk "$repo_root" | awk 'NR == 2 { print $4 }')"
    if test "$free_kib" -lt 104857600; then
      echo "server-recovery-test stops below 100 GiB of free space" >&2
      exit 1
    fi

    echo "server-recovery-test: declarative dummy-target boundary check"
    nix build \
      --no-link \
      --print-build-logs \
      --max-jobs 2 \
      --cores 2 \
      "path:$repo_root#checks.x86_64-linux.server-recovery-policy"

    echo "server-recovery-test: production server closure build without activation"
    nix build \
      --no-link \
      --print-build-logs \
      --max-jobs 2 \
      --cores 2 \
      "path:$repo_root#nixosConfigurations.server.config.system.build.toplevel"

    echo "server-recovery-test: isolated BIOS/disko install test"
    nixos-anywhere \
      --flake "path:$repo_root#server" \
      --build-on local \
      --vm-test \
      --option max-jobs 2 \
      --option cores 2

    echo "server-recovery-test: isolated dual-stack/SSH/firewall test"
    nix build \
      --no-link \
      --print-build-logs \
      --max-jobs 2 \
      --cores 2 \
      "path:$repo_root#checks.x86_64-linux.server-recovery-network"

    echo "server-recovery-test: PASS; no production target was accepted or contacted"
  '';
}
