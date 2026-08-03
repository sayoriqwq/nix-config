{
  pkgs,
  profilePackages,
}:

let
  inherit (pkgs) lib;

  packageNamed =
    name:
    let
      matches = lib.filter (package: lib.getName package == name) profilePackages;
    in
    assert lib.assertMsg (
      builtins.length matches == 1
    ) "macbook AI client profile must contain exactly one ${name} package";
    builtins.head matches;

  codex = packageNamed "codex-cli";
  claude = packageNamed "claude-code";
  antigravity = packageNamed "antigravity-cli";
  ohMyPi = packageNamed "oh-my-pi";

  excludedPackages = lib.filter (
    package:
    builtins.elem (lib.getName package) [
      "oh-my-codex"
      "omx"
    ]
  ) profilePackages;
in
assert lib.assertMsg (
  excludedPackages == [ ]
) "macbook AI client profile must not contain the out-of-scope oh-my-codex/omx package";
pkgs.runCommand "macbook-ai-clients-check"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.gnugrep
    ];
  }
  ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    export PATH="${codex}/bin:${claude}/bin:${antigravity}/bin:${ohMyPi}/bin:${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin"

    test -x "${codex}/bin/codex"
    test -x "${claude}/bin/claude"
    test -x "${antigravity}/bin/agy"
    test -x "${ohMyPi}/bin/omp"
    grep -Fq 'PI_CONFIG_FILES' "${ohMyPi}/bin/omp"
    grep -Fq 'checkUpdate: false' "${ohMyPi}/share/oh-my-pi/nix-managed.yml"

    codexVersion="$("${codex}/bin/codex" --version)"
    claudeVersion="$("${claude}/bin/claude" --version)"
    antigravityVersion="$("${antigravity}/bin/agy" --version)"
    ohMyPiVersion="$("${ohMyPi}/bin/omp" --version)"

    printf 'codex: %s\nclaude: %s\nantigravity: %s\noh-my-pi: %s\n' \
      "$codexVersion" "$claudeVersion" "$antigravityVersion" "$ohMyPiVersion"

    printf '%s\n' "$codexVersion" | grep -Fq '0.146.0'
    printf '%s\n' "$claudeVersion" | grep -Fq '2.1.187'
    printf '%s\n' "$antigravityVersion" | grep -Fq '1.1.9'
    printf '%s\n' "$ohMyPiVersion" | grep -Fq '17.2.4'

    touch "$out"
  ''
