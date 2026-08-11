{
  pkgs,
  contract,
  rimeIceSource,
  homeDirectory,
  behaviorReconciler ? null,
  fullCapability ? true,
}:

let
  inherit (pkgs) lib;
  quote = lib.escapeShellArg;
  targetRoot = "${homeDirectory}/${contract.targetRoot}";
  localOverlaySource = toString contract.localOverlay.source;
  localOverlayTarget = "${targetRoot}/${contract.localOverlay.relativePath}";
  mutablePaths = map (entry: "${homeDirectory}/${entry.relativePath}") contract.mutableStatePaths;
in
assert lib.assertMsg (
  builtins.length contract.managedPaths == 65
) "macbook Rime preflight requires the reviewed set of exactly 65 static leaves";
assert lib.assertMsg (
  homeDirectory == "/Users/sayori"
) "macbook Rime preflight must retain its fixed audited home target";
assert lib.assertMsg (contract.isSafeRelativePath contract.targetRoot)
  "macbook Rime preflight target root must be a safe relative path";
assert lib.assertMsg (lib.all contract.isSafeRelativePath contract.managedPaths)
  "macbook Rime preflight managed leaves must be safe relative paths";
assert lib.assertMsg (lib.all (entry: contract.isSafeRelativePath entry.relativePath)
  contract.mutableStatePaths
) "macbook Rime preflight mutable state paths must be fixed safe relative paths";
assert lib.assertMsg (lib.all (path: !(contract.isForbiddenManagedPath path))
  contract.managedPaths
) "macbook Rime preflight must not inspect mutable Rime paths as managed leaves";
assert lib.assertMsg (
  !fullCapability || behaviorReconciler != null
) "the full macbook Chinese-input preflight requires the behavior reconciler";
pkgs.writeShellApplication {
  name = "macbook-rime-preflight";
  runtimeInputs = [ pkgs.coreutils ];
  text = ''
    if test "$#" -ne 0; then
      echo "macbook-rime-preflight accepts no arguments" >&2
      exit 64
    fi

    if test "$(uname -s)" != "Darwin"; then
      echo "preflight: this fixed target is restricted to the macbook Darwin host" >&2
      exit 1
    fi

    source_root=${quote (toString rimeIceSource)}
    target_root=${quote targetRoot}

    source_root_real="$(realpath "$source_root")"
    case "$source_root_real" in
      /nix/store/*) ;;
      *)
        echo "preflight: pinned Rime source is not in the Nix store" >&2
        exit 1
        ;;
    esac

    if test -L "$target_root"; then
      echo "preflight: Rime target root must not be a symlink" >&2
      exit 1
    fi
    if test -e "$target_root" && ! test -d "$target_root"; then
      echo "preflight: Rime target root is not a directory" >&2
      exit 1
    fi

    target_root_real="$(realpath -m "$target_root")"
    case "$target_root_real" in
      /nix/store|/nix/store/*)
        echo "preflight: Rime target root resolves into the Nix store" >&2
        exit 1
        ;;
    esac

    check_static_leaf() {
      relative_path="$1"
      source_leaf="$source_root/$relative_path"
      live_leaf="$target_root/$relative_path"

      if ! test -f "$source_leaf" || test -L "$source_leaf"; then
        echo "preflight: source leaf is missing, non-regular, or a symlink: $relative_path" >&2
        return 1
      fi

      source_real="$(realpath "$source_leaf")"
      case "$source_real" in
        "$source_root_real"/*) ;;
        *)
          echo "preflight: source leaf escapes the pinned source: $relative_path" >&2
          return 1
          ;;
      esac

      if test -L "$live_leaf"; then
        live_real="$(realpath "$live_leaf" 2>/dev/null || true)"
        if test "$live_real" != "$source_real"; then
          echo "preflight: managed symlink does not resolve to its pinned source: $relative_path" >&2
          return 1
        fi
      elif test -f "$live_leaf"; then
        live_real="$(realpath "$live_leaf")"
        case "$live_real" in
          "$target_root_real"/*) ;;
          *)
            echo "preflight: regular managed leaf escapes the Rime target root: $relative_path" >&2
            return 1
            ;;
        esac

        source_hash="$(sha256sum "$source_leaf" | cut -d ' ' -f 1)"
        live_hash="$(sha256sum "$live_leaf" | cut -d ' ' -f 1)"
        if test "$live_hash" != "$source_hash"; then
          echo "preflight: managed leaf content drift: $relative_path" >&2
          return 1
        fi
      elif test -e "$live_leaf"; then
        echo "preflight: managed leaf has an unsupported file type: $relative_path" >&2
        return 1
      else
        echo "preflight: managed leaf is missing: $relative_path" >&2
        return 1
      fi
    }

    ${lib.concatMapStringsSep "\n" (path: "check_static_leaf ${quote path}") contract.managedPaths}

    ${lib.optionalString fullCapability ''
      overlay_source=${quote localOverlaySource}
      overlay_target=${quote localOverlayTarget}
      overlay_relative=${quote contract.localOverlay.relativePath}
      overlay_source_real="$(realpath "$overlay_source")"

      if ! test -f "$overlay_source" || test -L "$overlay_source"; then
        echo "preflight: local overlay source is missing, non-regular, or a symlink: $overlay_relative" >&2
        exit 1
      fi
      case "$overlay_source_real" in
        /nix/store/*) ;;
        *)
          echo "preflight: local overlay source is not in the Nix store" >&2
          exit 1
          ;;
      esac

      if test -L "$overlay_target"; then
        overlay_live_real="$(realpath "$overlay_target" 2>/dev/null || true)"
        if test "$overlay_live_real" != "$overlay_source_real"; then
          echo "preflight: local overlay symlink does not resolve to its declared source" >&2
          exit 1
        fi
      elif test -f "$overlay_target"; then
        overlay_live_real="$(realpath "$overlay_target")"
        case "$overlay_live_real" in
          "$target_root_real"/*) ;;
          *)
            echo "preflight: regular local overlay escapes the Rime target root" >&2
            exit 1
            ;;
        esac
        overlay_source_hash="$(sha256sum "$overlay_source" | cut -d ' ' -f 1)"
        overlay_live_hash="$(sha256sum "$overlay_target" | cut -d ' ' -f 1)"
        if test "$overlay_live_hash" != "$overlay_source_hash"; then
          echo "preflight: local overlay content drift" >&2
          exit 1
        fi
      elif test -e "$overlay_target"; then
        echo "preflight: local overlay has an unsupported file type" >&2
        exit 1
      else
        echo "preflight: local overlay is missing" >&2
        exit 1
      fi
    ''}

    check_mutable_path_metadata() {
      mutable_path="$1"
      # stat is deliberately non-recursive. It reads only the path's own
      # lstat metadata; no userdb or sync entry is opened, listed, or hashed.
      if test -e "$mutable_path" || test -L "$mutable_path"; then
        stat --format='%F' -- "$mutable_path" >/dev/null
      fi

      mutable_real="$(realpath -m "$mutable_path")"
      case "$mutable_real" in
        /nix/store|/nix/store/*)
          echo "preflight: mutable state resolves into the Nix store: $mutable_path" >&2
          return 1
          ;;
      esac
    }

    ${lib.concatMapStringsSep "\n" (path: "check_mutable_path_metadata ${quote path}") mutablePaths}

    ${lib.optionalString fullCapability ''
      ${lib.getExe behaviorReconciler} check
    ''}

    ${
      if fullCapability then
        ''
          echo "preflight: 65 pinned Rime leaves and 1 local overlay match their declarations"
          echo "preflight: approved Fcitx5 behavior and Keep invariants match the contract"
        ''
      else
        ''
          echo "preflight: 65 pinned Rime leaves match the static handoff contract"
        ''
    }
    echo "preflight: mutable state paths remain outside the Nix store"
  '';
}
