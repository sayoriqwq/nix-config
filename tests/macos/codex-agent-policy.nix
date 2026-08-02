{
  homeConfiguration,
  pkgs,
}:

let
  inherit (pkgs) lib;

  target = ".codex/AGENTS.md";
  policy = homeConfiguration.home.file.${target};
  managedCodexFiles = lib.filter (path: lib.hasPrefix ".codex/" path) (
    builtins.attrNames homeConfiguration.home.file
  );
  codexStatePaths = lib.filter (
    entry: entry.path == "${homeConfiguration.home.homeDirectory}/.codex"
  ) homeConfiguration.sayori.statePaths;
  codexStatePath = builtins.head codexStatePaths;
in
assert lib.assertMsg (
  managedCodexFiles == [ target ]
) "macbook must manage only the reviewed global Codex AGENTS.md inside ~/.codex";
assert lib.assertMsg policy.force "macbook global Codex AGENTS.md must replace mutable drift";
assert lib.assertMsg (
  builtins.length codexStatePaths == 1
) "macbook must retain exactly one mutable Codex state-path declaration";
assert lib.assertMsg (lib.hasInfix "AGENTS.md" codexStatePath.description)
  "macbook Codex state-path declaration must document the managed AGENTS.md exception";
pkgs.runCommand "macbook-codex-agent-policy-check"
  {
    nativeBuildInputs = [ pkgs.gnugrep ];
  }
  ''
    policy=${policy.source}

    test -f "$policy"
    grep -Fq '/Users/sayori/Desktop/nix-config' "$policy"
    grep -Fq '/etc/profiles/per-user/sayori/bin/python' "$policy"
    grep -Fq 'The baseline intentionally has no global `pip`' "$policy"
    grep -Fq 'uv owns project Python selection' "$policy"
    grep -Fq 'Persistent user-global CLI tools default to a declaration' "$policy"
    grep -Fq 'Never run nix-darwin, Home Manager, or NixOS activation commands' "$policy"
    grep -Fq "/etc/profiles/per-user/sayori/bin/fish -lc" "$policy"
    grep -Fq 'rtk git status' "$policy"

    if grep -Eq '/nix/store/[0-9a-z]{32}-' "$policy"; then
      echo 'global Codex policy must not hard-code a Nix Store derivation path' >&2
      exit 1
    fi

    touch "$out"
  ''
