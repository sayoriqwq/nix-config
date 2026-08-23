{
  nixosAnywherePackage,
  pkgs,
}:

pkgs.writeShellApplication {
  name = "server-recovery-test";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.gawk
    pkgs.git
    pkgs.nix
    nixosAnywherePackage
  ];
  text = ''
    if test "$#" -ne 0; then
      echo "server-recovery-test accepts no target or extra arguments" >&2
      exit 64
    fi

    if test "$(uname -s)" != Linux || test "$(uname -m)" != x86_64; then
      echo "server-recovery-test must run on x86_64-linux" >&2
      exit 1
    fi

    if ! test -r /dev/kvm || ! test -w /dev/kvm; then
      echo "server-recovery-test requires user-accessible /dev/kvm" >&2
      exit 1
    fi

    repo_root="$(git rev-parse --show-toplevel)"
    if test -n "$(git -C "$repo_root" status --porcelain=v1 --untracked-files=normal)"; then
      echo "server-recovery-test requires a clean checkout" >&2
      exit 1
    fi

    available_kib="$(df -Pk "$repo_root" | awk 'NR == 2 { print $4 }')"
    required_kib=$((100 * 1024 * 1024))
    if test "$available_kib" -lt "$required_kib"; then
      echo "server-recovery-test requires at least 100 GiB of free space" >&2
      exit 1
    fi

    flake_ref="path:$repo_root"

    echo "server-recovery-test: production policy and runner boundary"
    nix build --no-link "$flake_ref#checks.x86_64-linux.server-recovery-policy"

    echo "server-recovery-test: production server closure without activation"
    nix build --no-link "$flake_ref#nixosConfigurations.server.config.system.build.toplevel"

    echo "server-recovery-test: isolated BIOS/disko installation"
    nixos-anywhere --flake "$flake_ref#server-recovery-install" --vm-test

    echo "server-recovery-test: isolated network, SSH and firewall behavior"
    nix build --no-link "$flake_ref#checks.x86_64-linux.server-recovery-network"

    echo "server-recovery-test: PASS; no production target was accepted or contacted"
  '';
}
