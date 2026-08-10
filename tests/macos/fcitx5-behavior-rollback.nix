{
  pkgs,
  lib,
  contract,
  behaviorReconciler,
  homeDirectory,
  configurationRevision,
}:

let
  journalRoot = "${homeDirectory}/${contract.behavior.journal.relativePath}";
in
assert lib.assertMsg (
  homeDirectory == "/Users/sayori"
) "the Fcitx5 behavior rollback helper must retain its fixed audited home target";
pkgs.writeShellApplication {
  name = "macbook-fcitx5-behavior-rollback";
  runtimeInputs = [ pkgs.gitMinimal ];
  text = ''
    if test "$#" -ne 1 || test "$1" != "--confirm-approved-behavior-rollback"; then
      echo "macbook-fcitx5-behavior-rollback requires the explicit approval flag" >&2
      exit 2
    fi

    if test "$(uname -s)" != "Darwin"; then
      echo "behavior rollback: this helper is restricted to the macbook Darwin host" >&2
      exit 1
    fi

    expected_revision=${lib.escapeShellArg configurationRevision}
    case "$expected_revision" in
      ""|*-dirty)
        echo "behavior rollback: build this helper from the clean, reviewed Git commit" >&2
        exit 1
        ;;
    esac

    repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if test -z "$repo_root" || test -n "$(git -C "$repo_root" status --porcelain)"; then
      echo "behavior rollback: run from the clean, reviewed nix-config checkout" >&2
      exit 1
    fi
    if test "$(git -C "$repo_root" rev-parse HEAD)" != "$expected_revision"; then
      echo "behavior rollback: checkout HEAD does not match the helper's reviewed commit" >&2
      exit 1
    fi

    ${lib.getExe behaviorReconciler} rollback ${lib.escapeShellArg journalRoot}
    echo "behavior rollback: approved Fcitx5 fields restored from the semantic journal"
    echo "behavior rollback: no activation, restart, or Rime deployment was performed"
  '';
}
