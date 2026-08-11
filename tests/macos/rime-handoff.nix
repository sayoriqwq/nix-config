{
  configurationRevision,
  contract,
  homeDirectory,
  pkgs,
  preflight,
}:

let
  inherit (pkgs.lib) escapeShellArg;
  targetRoot = "${homeDirectory}/${contract.targetRoot}";
  copyManagedLeaves = pkgs.lib.concatMapStringsSep "\n" (relativePath: ''
    relative_path=${escapeShellArg relativePath}
    live_path="$target_root/$relative_path"
    backup_path="$backup_dir/$relative_path"

    if test -L "$live_path" || ! test -f "$live_path"; then
      echo "handoff: expected an unmanaged regular leaf: $relative_path" >&2
      exit 1
    fi

    mkdir -p "$(dirname "$backup_path")"
    cp -p -- "$live_path" "$backup_path"
    (
      cd "$backup_dir"
      sha256sum -- "$relative_path" >> "$checksum_manifest"
    )
  '') contract.managedPaths;
  releaseManagedLeaves = pkgs.lib.concatMapStringsSep "\n" (relativePath: ''
    relative_path=${escapeShellArg relativePath}
    live_path="$target_root/$relative_path"
    backup_path="$backup_dir/$relative_path"
    released_path="$released_root/$relative_path"

    mkdir -p "$(dirname "$released_path")"
    printf '%s\n' "$relative_path" >> "$release_manifest"
    mv --no-clobber -- "$live_path" "$released_path"
    if test -e "$live_path" || test -L "$live_path"; then
      echo "handoff: live leaf changed or reappeared during release: $relative_path" >&2
      exit 1
    fi
    if ! test -f "$released_path" || test -L "$released_path"; then
      echo "handoff: released leaf is missing, non-regular, or a symlink: $relative_path" >&2
      exit 1
    fi
    if ! cmp --silent "$released_path" "$backup_path"; then
      echo "handoff: live leaf drifted after backup and was retained for recovery: $relative_path" >&2
      exit 1
    fi
  '') contract.managedPaths;
in
pkgs.writeShellApplication {
  name = "macbook-rime-handoff";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.gitMinimal
  ];
  text = ''
    if test "$#" -ne 1 || test "$1" != "--confirm-approved-static-handoff"; then
      echo "macbook-rime-handoff requires the explicit approval flag" >&2
      exit 2
    fi

    if test "$(uname -s)" != "Darwin"; then
      echo "handoff: this helper is restricted to the macbook Darwin host" >&2
      exit 1
    fi

    expected_revision=${escapeShellArg configurationRevision}
    case "$expected_revision" in
      ""|*-dirty)
        echo "handoff: build this helper from the clean, reviewed Git commit" >&2
        exit 1
        ;;
    esac

    repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if test -z "$repo_root"; then
      echo "handoff: run this helper from the reviewed nix-config checkout" >&2
      exit 1
    fi
    if test -n "$(git -C "$repo_root" status --porcelain)"; then
      echo "handoff: the reviewed nix-config checkout must be clean" >&2
      exit 1
    fi

    config_revision="$(git -C "$repo_root" rev-parse HEAD)"
    if test "$config_revision" != "$expected_revision"; then
      echo "handoff: checkout HEAD does not match the helper's reviewed commit" >&2
      exit 1
    fi
    target_root=${escapeShellArg targetRoot}
    backup_root=${escapeShellArg "${homeDirectory}/.local/state/nix-config/rime-static-handoff"}
    backup_dir="$backup_root/$config_revision"
    checksum_manifest="$backup_dir/SHA256SUMS"
    release_manifest="$backup_dir/RELEASED"
    released_root="$backup_dir/.released"

    if test -L "$backup_root"; then
      echo "handoff: rollback root must not be a symlink" >&2
      exit 1
    fi
    if test -e "$backup_root" && ! test -d "$backup_root"; then
      echo "handoff: rollback root is not a directory" >&2
      exit 1
    fi

    if test -e "$backup_dir" || test -L "$backup_dir"; then
      echo "handoff: rollback directory already exists for revision $config_revision" >&2
      exit 1
    fi
    if test -e "$backup_root/current" || test -L "$backup_root/current"; then
      echo "handoff: an earlier static handoff still owns $backup_root/current" >&2
      exit 1
    fi

    ${preflight}/bin/macbook-rime-preflight

    umask 077
    mkdir -p "$backup_dir"
    chmod 700 "$backup_root" "$backup_dir"
    if test "$(realpath "$backup_root")" != "$backup_root"; then
      echo "handoff: rollback root must not traverse a symlink" >&2
      exit 1
    fi
    if test "$(stat --format='%u:%a' "$backup_root")" != "$(id -u):700" \
      || test "$(stat --format='%u:%a' "$backup_dir")" != "$(id -u):700"; then
      echo "handoff: rollback evidence must remain owner-only" >&2
      exit 1
    fi

    ${copyManagedLeaves}

    (
      cd "$backup_dir"
      sha256sum --check --quiet SHA256SUMS
    )

    {
      echo "configuration-revision=$config_revision"
      echo "rime-ice-release=${contract.release}"
      echo "rime-ice-revision=${contract.revision}"
      echo "target-root=$target_root"
      echo "created-at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    } > "$backup_dir/HANDOFF"

    # Close the copy/unlink race: verify the live tree against the immutable
    # source again, then atomically move each current leaf into owner-only
    # recovery storage and compare the moved inode with the checked backup.
    ${preflight}/bin/macbook-rime-preflight

    handoff_complete=0
    restore_partial_handoff() {
      exit_status="$?"
      set +e
      if test "$handoff_complete" -eq 0 && test -f "$release_manifest"; then
        restore_errors=0
        echo "handoff: release failed; restoring any leaves already moved" >&2
        while IFS= read -r relative_path; do
          live_path="$target_root/$relative_path"
          released_path="$released_root/$relative_path"
          if test -f "$released_path" && ! test -L "$released_path" \
            && ! test -e "$live_path" && ! test -L "$live_path"; then
            mkdir -p "$(dirname "$live_path")"
            mv --no-clobber -- "$released_path" "$live_path"
            if test -e "$released_path" || test -L "$released_path" \
              || ! test -f "$live_path" || test -L "$live_path"; then
              echo "handoff: automatic recovery failed: $relative_path" >&2
              restore_errors=1
            fi
          elif test -e "$released_path" || test -L "$released_path"; then
            echo "handoff: recovery conflict; retained moved leaf at $released_path" >&2
            restore_errors=1
          fi
        done < "$release_manifest"
        if test "$restore_errors" -ne 0; then
          echo "handoff: partial recovery evidence remains at $backup_dir" >&2
        fi
      fi
      exit "$exit_status"
    }
    trap restore_partial_handoff EXIT

    ${releaseManagedLeaves}

    ln -s "$backup_dir" "$backup_root/current"
    handoff_complete=1
    trap - EXIT
    echo "handoff: PASS; 65 static leaves released"
    echo "handoff: rollback=$backup_dir"
    echo "handoff: no activation or Rime deployment was performed"
  '';
}
