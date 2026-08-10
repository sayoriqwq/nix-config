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
  verifyBackupLeaves = pkgs.lib.concatMapStringsSep "\n" (relativePath: ''
    relative_path=${escapeShellArg relativePath}
    backup_path="$backup_dir/$relative_path"
    if ! test -f "$backup_path" || test -L "$backup_path"; then
      echo "rollback: backup leaf is missing, non-regular, or a symlink: $relative_path" >&2
      exit 1
    fi
    backup_real="$(realpath "$backup_path")"
    case "$backup_real" in
      "$backup_dir"/*) ;;
      *)
        echo "rollback: backup leaf escapes its owner-only root: $relative_path" >&2
        exit 1
        ;;
    esac
    (
      cd "$backup_dir"
      sha256sum -- "$relative_path" >> "$computed_manifest"
    )
  '') contract.managedPaths;
  prepareManagedLeaves = pkgs.lib.concatMapStringsSep "\n" (relativePath: ''
    relative_path=${escapeShellArg relativePath}
    backup_path="$backup_dir/$relative_path"
    staged_path="$staged_root/$relative_path"
    mkdir -p "$(dirname "$staged_path")"
    cp -p -- "$backup_path" "$staged_path"
    if ! test -f "$staged_path" || test -L "$staged_path" \
      || ! cmp --silent "$staged_path" "$backup_path"; then
      echo "rollback: failed to stage an exact static leaf: $relative_path" >&2
      exit 1
    fi
  '') contract.managedPaths;
  assertTargetsAbsent = pkgs.lib.concatMapStringsSep "\n" (relativePath: ''
    relative_path=${escapeShellArg relativePath}
    live_path="$target_root/$relative_path"
    if test -e "$live_path" || test -L "$live_path"; then
      echo "rollback: target must be absent after selecting the previous generation: $relative_path" >&2
      exit 1
    fi
  '') contract.managedPaths;
  restoreManagedLeaves = pkgs.lib.concatMapStringsSep "\n" (relativePath: ''
    relative_path=${escapeShellArg relativePath}
    backup_path="$backup_dir/$relative_path"
    staged_path="$staged_root/$relative_path"
    live_path="$target_root/$relative_path"
    mkdir -p "$(dirname "$live_path")"
    printf '%s\n' "$relative_path" >> "$restored_manifest"
    mv --no-clobber -- "$staged_path" "$live_path"
    if test -e "$staged_path" || test -L "$staged_path" \
      || ! test -f "$live_path" || test -L "$live_path" \
      || ! cmp --silent "$live_path" "$backup_path"; then
      echo "rollback: failed to restore an exact static leaf: $relative_path" >&2
      exit 1
    fi
  '') contract.managedPaths;
in
pkgs.writeShellApplication {
  name = "macbook-rime-static-rollback";
  runtimeInputs = [ pkgs.coreutils ];
  text = ''
    if test "$#" -ne 1 || test "$1" != "--confirm-approved-static-rollback"; then
      echo "macbook-rime-static-rollback requires the explicit approval flag" >&2
      exit 2
    fi

    if test "$(uname -s)" != "Darwin"; then
      echo "rollback: this helper is restricted to the macbook Darwin host" >&2
      exit 1
    fi

    expected_revision=${escapeShellArg configurationRevision}
    case "$expected_revision" in
      ""|*-dirty)
        echo "rollback: build this helper from the clean, reviewed Git commit" >&2
        exit 1
        ;;
    esac

    target_root=${escapeShellArg targetRoot}
    backup_root=${escapeShellArg "${homeDirectory}/.local/state/nix-config/rime-static-handoff"}
    current_backup="$backup_root/current"

    if test -L "$backup_root" || ! test -d "$backup_root" \
      || test "$(realpath "$backup_root")" != "$backup_root"; then
      echo "rollback: rollback root is missing or traverses a symlink" >&2
      exit 1
    fi
    if test "$(stat --format='%u:%a' "$backup_root")" != "$(id -u):700"; then
      echo "rollback: rollback root is not owner-only" >&2
      exit 1
    fi
    if ! test -L "$current_backup"; then
      echo "rollback: current static rollback pointer is missing" >&2
      exit 1
    fi
    backup_dir="$(realpath "$current_backup")"
    case "$backup_dir" in
      "$backup_root"/*) ;;
      *)
        echo "rollback: rollback pointer escapes its owner-only root" >&2
        exit 1
        ;;
    esac
    if test "$(stat --format='%u:%a' "$backup_dir")" != "$(id -u):700"; then
      echo "rollback: rollback directory is not owner-only" >&2
      exit 1
    fi

    if test -L "$target_root"; then
      echo "rollback: Rime user-data root must remain a writable directory" >&2
      exit 1
    fi
    if ! test -f "$backup_dir/SHA256SUMS" || test -L "$backup_dir/SHA256SUMS" \
      || ! test -f "$backup_dir/HANDOFF" || test -L "$backup_dir/HANDOFF"; then
      echo "rollback: rollback evidence is incomplete" >&2
      exit 1
    fi
    if test "$(head -n 1 "$backup_dir/HANDOFF")" != "configuration-revision=$expected_revision"; then
      echo "rollback: rollback evidence belongs to a different configuration revision" >&2
      exit 1
    fi

    umask 077
    staging_dir="$(mktemp -d "$backup_root/.rime-static-rollback.XXXXXX")"
    staged_root="$staging_dir/static"
    computed_manifest="$staging_dir/SHA256SUMS"
    restored_manifest="$staging_dir/RESTORED"
    : > "$computed_manifest"

    rollback_complete=0
    revert_partial_rollback() {
      exit_status="$?"
      set +e
      if test "$rollback_complete" -eq 0 && test -f "$restored_manifest"; then
        revert_errors=0
        echo "rollback: restore failed; returning exact restored leaves to staging" >&2
        while IFS= read -r relative_path; do
          backup_path="$backup_dir/$relative_path"
          staged_path="$staged_root/$relative_path"
          live_path="$target_root/$relative_path"
          if test -f "$live_path" && ! test -L "$live_path" \
            && cmp --silent "$live_path" "$backup_path"; then
            mkdir -p "$(dirname "$staged_path")"
            mv --no-clobber -- "$live_path" "$staged_path"
            if test -e "$live_path" || test -L "$live_path" \
              || ! test -f "$staged_path" || test -L "$staged_path"; then
              echo "rollback: automatic partial-restore reversal failed: $relative_path" >&2
              revert_errors=1
            fi
          elif test -e "$live_path" || test -L "$live_path"; then
            echo "rollback: reversal conflict; preserved live path: $relative_path" >&2
            revert_errors=1
          fi
        done < "$restored_manifest"
        if test "$revert_errors" -ne 0; then
          echo "rollback: recovery evidence remains at $staging_dir" >&2
        fi
      fi
      exit "$exit_status"
    }
    trap revert_partial_rollback EXIT

    ${verifyBackupLeaves}
    if ! cmp --silent "$computed_manifest" "$backup_dir/SHA256SUMS"; then
      echo "rollback: static rollback checksums or path set do not match" >&2
      exit 1
    fi

    ${prepareManagedLeaves}
    ${assertTargetsAbsent}
    ${restoreManagedLeaves}

    ${preflight}/bin/macbook-rime-preflight
    rollback_complete=1
    trap - EXIT
    rm -r -- "$staging_dir"
    echo "rollback: PASS; 65 static regular files restored"
    echo "rollback: no user database, sync state, activation, or Rime deployment was modified"
  '';
}
