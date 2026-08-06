{
  homeConfiguration,
  pkgs,
  profilePackages,
}:

let
  inherit (pkgs) lib;

  rtkPackages = lib.filter (package: lib.getName package == "rtk") profilePackages;
  rtk = builtins.head rtkPackages;
  codexStatePaths = lib.filter (
    entry: entry.path == "${homeConfiguration.home.homeDirectory}/.codex"
  ) homeConfiguration.sayori.statePaths;
  codexStatePath = builtins.head codexStatePaths;
in
assert lib.assertMsg (
  builtins.length rtkPackages == 1
) "macbook AI capability must provide exactly one Nix-managed RTK CLI";
assert lib.assertMsg (
  !(builtins.hasAttr ".codex/RTK.md" homeConfiguration.home.file)
) "RTK.md must remain an RTK CLI-generated artifact outside the Nix Store";
assert lib.assertMsg (lib.hasInfix "RTK.md" codexStatePath.description)
  "macbook Codex state-path declaration must document RTK.md ownership";
pkgs.runCommand "macbook-rtk-integration-check"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      rtk
    ];
  }
  ''
    export HOME="$TMPDIR/home"
    export CODEX_HOME="$HOME/.codex"
    output="$TMPDIR/rtk-init-dry-run.txt"

    rtk -v init -g --codex --dry-run > "$output"

    test ! -e "$CODEX_HOME"
    grep -Fq "[dry-run] would create RTK.md: $CODEX_HOME/RTK.md" "$output"
    grep -Fq '# RTK - Rust Token Killer (Codex CLI)' "$output"
    grep -Fq "[dry-run] would add @$CODEX_HOME/RTK.md reference to AGENTS.md: $CODEX_HOME/AGENTS.md" "$output"
    grep -Fq '[dry-run] Nothing written.' "$output"
    rtk --version | grep -Eq '^rtk [0-9]+\.[0-9]+\.[0-9]+'

    touch "$out"
  ''
