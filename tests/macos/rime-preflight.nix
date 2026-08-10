{
  pkgs,
  contract,
  rimeIceSource,
  homeDirectory,
}:

let
  inherit (pkgs) lib;
  quote = lib.escapeShellArg;
  targetRoot = "${homeDirectory}/${contract.targetRoot}";
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

    echo "preflight: 65 Rime static leaves match the pinned ${contract.release} source"
    echo "preflight: mutable state paths remain outside the Nix store"
  '';
}
