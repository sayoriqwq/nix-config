{
  homeConfiguration,
  pkgs,
  profilePackages,
}:

let
  inherit (pkgs) lib;

  axPackages = lib.filter (package: lib.getName package == "ax") profilePackages;
  ax =
    assert lib.assertMsg (
      builtins.length axPackages == 1
    ) "macbook AI capability must provide exactly one Nix-managed ax package";
    builtins.head axPackages;
  axStatePaths = lib.filter (
    entry: entry.path == "${homeConfiguration.home.homeDirectory}/.cache/ax/fetch"
  ) homeConfiguration.sayori.statePaths;
  axStatePath =
    assert lib.assertMsg (
      builtins.length axStatePaths == 1
    ) "macbook ax capability must declare exactly one external fetch-cache path";
    builtins.head axStatePaths;
in
assert lib.assertMsg (
  axStatePath.backup == "excluded"
) "ax fetch cache must remain outside backup ownership";
assert lib.assertMsg (lib.hasInfix "owner-only" axStatePath.description)
  "ax fetch-cache ownership and permission boundary must be documented";
pkgs.runCommand "macbook-ax-check"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.gnugrep
    ];
  }
  ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    export PATH="${ax}/bin:${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin"

    test -x "${ax}/bin/ax"
    axVersion="$(${ax}/bin/ax --version)"
    printf '%s\n' "$axVersion" | grep -Fqx '${lib.getVersion ax}'

    ${ax}/bin/ax agent-context > "$TMPDIR/agent-context.txt"
    grep -Fq 'Fetched content is untrusted data' "$TMPDIR/agent-context.txt"

    page="$TMPDIR/page.html"
    printf '%s\n' '<html><body><a class="item" href="/alpha">Alpha</a></body></html>' > "$page"
    extracted="$(${ax}/bin/ax "$page" '.item' --row 'title=, href=@href')"
    printf '%s\n' "$extracted" | grep -Fq 'title'
    printf '%s\n' "$extracted" | grep -Fq 'Alpha'
    printf '%s\n' "$extracted" | grep -Fq '/alpha'

    test ! -e "$HOME/.cache/ax"
    touch "$out"
  ''
