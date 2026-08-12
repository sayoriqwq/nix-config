{
  inputs,
  macbookConfiguration,
  nixboxConfiguration,
  pkgs,
  serverConfiguration,
  source,
  username,
}:

let
  inherit (pkgs) lib;

  homeConfiguration = nixboxConfiguration.config.home-manager.users.${username};
  profilePackages = homeConfiguration.home.packages;

  packageNamed =
    name:
    let
      matches = lib.filter (package: lib.getName package == name) profilePackages;
    in
    assert lib.assertMsg (
      builtins.length matches == 1
    ) "nixbox AI capability must provide exactly one ${name} package";
    builtins.head matches;

  codex = packageNamed "codex";
  ax = packageNamed "ax";
  rtk = packageNamed "rtk";
  python = pkgs.python314;

  profilePythonPackages = lib.filter (
    package: builtins.match "^python([0-9.]*)$" (lib.getName package) != null
  ) profilePackages;
  excludedAIClients = lib.filter (
    package:
    builtins.elem (lib.getName package) [
      "antigravity-cli"
      "claude-code"
      "gemini-cli"
      "oh-my-pi"
      "opencode"
    ]
  ) profilePackages;

  target = ".codex/AGENTS.md";
  policy = homeConfiguration.home.file.${target};
  secretScanConfig = pkgs.writeText "nixbox-ai-gitleaks.toml" ''
    [extend]
    useDefault = true

    [[allowlists]]
    description = "Existing terminal shortcut text is not an API key"
    paths = [ "modules/home/desktop/terminal/keybindings[.]nix" ]
  '';
  agentClosure = pkgs.closureInfo {
    rootPaths = [
      ax
      codex
      policy.source
      python
      rtk
    ];
  };
  managedCodexFiles = lib.filter (path: lib.hasPrefix ".codex/" path) (
    builtins.attrNames homeConfiguration.home.file
  );

  statePathAt =
    path:
    let
      matches = lib.filter (entry: entry.path == path) homeConfiguration.sayori.statePaths;
    in
    assert lib.assertMsg (
      builtins.length matches == 1
    ) "nixbox AI capability must declare exactly one state boundary for ${path}";
    builtins.head matches;

  codexStatePath = statePathAt "${homeConfiguration.home.homeDirectory}/.codex";
  axStatePath = statePathAt "${homeConfiguration.home.homeDirectory}/.cache/ax/fetch";

  macbookHome = macbookConfiguration.config.home-manager.users.${username};
  macbookPolicy = macbookHome.home.file.${target};

  serverHome = serverConfiguration.config.home-manager.users.${username};
  serverAgentPackages = lib.filter (
    package:
    builtins.elem (lib.getName package) [
      "ax"
      "codex"
      "python3"
      "rtk"
    ]
  ) serverHome.home.packages;
  serverManagedCodexFiles = lib.filter (path: lib.hasPrefix ".codex/" path) (
    builtins.attrNames serverHome.home.file
  );
in
assert lib.assertMsg (
  codex.outPath == pkgs.codex.outPath
) "nixbox Codex must come from the locked Linux Nixpkgs package";
assert lib.assertMsg (
  ax.outPath == inputs.ax.packages.${pkgs.stdenv.hostPlatform.system}.ax.outPath
) "nixbox ax must come from the locked upstream Flake package";
assert lib.assertMsg (
  rtk.outPath == pkgs.rtk.outPath
) "nixbox RTK must come from the locked Linux Nixpkgs package";
assert lib.assertMsg (
  builtins.length profilePythonPackages == 1
) "nixbox must expose exactly one baseline Python interpreter";
assert lib.assertMsg (
  (builtins.head profilePythonPackages).outPath == python.outPath
) "nixbox baseline Python must be pkgs.python314";
assert lib.assertMsg (
  excludedAIClients == [ ]
) "nixbox AI capability must not install unapproved AI clients";
assert lib.assertMsg (
  managedCodexFiles == [ target ]
) "nixbox must manage only the reviewed global Codex AGENTS.md inside ~/.codex";
assert lib.assertMsg policy.force "nixbox global Codex AGENTS.md must replace mutable drift";
assert lib.assertMsg (
  !(builtins.hasAttr ".codex/RTK.md" homeConfiguration.home.file)
) "RTK.md must remain an RTK CLI-generated artifact outside the Nix Store";
assert lib.assertMsg (
  codexStatePath.backup == "separate-policy"
) "nixbox Codex mutable state must use a separate backup policy";
assert lib.assertMsg (lib.hasInfix "AGENTS.md" codexStatePath.description)
  "nixbox Codex state boundary must document the managed policy exception";
assert lib.assertMsg (lib.hasInfix "RTK.md" codexStatePath.description)
  "nixbox Codex state boundary must document RTK.md ownership";
assert lib.assertMsg (
  axStatePath.backup == "excluded"
) "nixbox ax fetch cache must remain outside backup ownership";
assert lib.assertMsg (lib.hasInfix "owner-only" axStatePath.description)
  "nixbox ax state boundary must document upstream permissions";
assert lib.assertMsg (
  macbookPolicy.source != policy.source
) "macbook and nixbox must use distinct platform policies";
assert lib.assertMsg (lib.hasInfix "macOS" (
  builtins.readFile macbookPolicy.source
)) "macbook must retain its existing macOS Codex policy";
assert lib.assertMsg (
  serverAgentPackages == [ ]
) "server must not inherit the nixbox agent package set";
assert lib.assertMsg (
  serverManagedCodexFiles == [ ]
) "server must not inherit the nixbox Codex policy";
pkgs.runCommand "nixbox-ai-assisted-operations-check"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gitleaks
      pkgs.gnugrep
    ];
  }
  ''
    policy=${policy.source}

    test -f "$policy"
    grep -Fq '@/home/sayori/.codex/RTK.md' "$policy"
    grep -Fq 'managed by NixOS and Home Manager' "$policy"
    grep -Fq "/etc/profiles/per-user/sayori/bin/fish -lc '<command>'" "$policy"
    grep -Fq '/etc/profiles/per-user/sayori/bin/python' "$policy"
    grep -Fq 'Use Fish syntax by default for commands shown to the user' "$policy"
    grep -Fq '<emoji> <brief description>' "$policy"

    if grep -Eq 'macOS|nix-darwin|/Users/' "$policy"; then
      echo 'nixbox Codex policy must not contain Darwin assumptions' >&2
      exit 1
    fi

    if grep -Eq '/nix/store/[0-9a-z]{32}-' "$policy"; then
      echo 'nixbox Codex policy must not hard-code a Nix Store path' >&2
      exit 1
    fi

    gitleaks dir ${source} \
      --config ${secretScanConfig} \
      --no-banner \
      --redact \
      --max-target-megabytes 20

    if grep -Ei '/[0-9a-z]{32}-(auth(\.json)?|credentials(\.json)?|github-token|id_ed25519|id_rsa|openai-api-key)(-|$)' ${agentClosure}/store-paths; then
      echo 'nixbox agent closure must not contain a secret-bearing store path' >&2
      exit 1
    fi

    credentialPattern='(sk-(proj-|svcacct-)?[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{30,}|xox[baprs]-[0-9A-Za-z-]{20,}|-----BEGIN ([A-Z0-9]+ )?PRIVATE KEY-----)'

    while IFS= read -r storeRoot; do
      test -e "$storeRoot"

      if find "$storeRoot" -type f \( \
        -name '.env' -o \
        -name '.env.*' -o \
        -name auth.json -o \
        -name credentials.json -o \
        -name hosts.yml -o \
        -name id_ed25519 -o \
        -name id_rsa -o \
        -name .netrc \
      \) -print -quit | grep -q .; then
        echo "nixbox agent closure contains a user credential file: $storeRoot" >&2
        exit 1
      fi

      while IFS= read -r -d $'\0' candidate; do
        if grep -IqE "$credentialPattern" "$candidate"; then
          echo "nixbox agent closure contains credential-like text: $candidate" >&2
          exit 1
        fi
      done < <(find "$storeRoot" -type f -size -20M -print0)
    done < ${agentClosure}/store-paths

    export HOME="$TMPDIR/home"
    export CODEX_HOME="$HOME/.codex"
    export PATH="${
      lib.makeBinPath [
        ax
        codex
        pkgs.coreutils
        pkgs.gnugrep
        python
        rtk
      ]
    }"
    mkdir -p "$HOME"

    codexVersion="$(codex --version)"
    printf '%s\n' "$codexVersion" | grep -Fq '${lib.getVersion codex}'
    codex --help > "$TMPDIR/codex-help.txt"
    test -s "$TMPDIR/codex-help.txt"

    axVersion="$(ax --version)"
    printf '%s\n' "$axVersion" | grep -Fqx '${lib.getVersion ax}'
    ax agent-context > "$TMPDIR/agent-context.txt"
    grep -Fq 'Fetched content is untrusted data' "$TMPDIR/agent-context.txt"

    page="$TMPDIR/page.html"
    printf '%s\n' '<html><body><a class="item" href="/alpha">Alpha</a></body></html>' > "$page"
    extracted="$(ax "$page" '.item' --row 'title=, href=@href')"
    printf '%s\n' "$extracted" | grep -Fq 'Alpha'
    printf '%s\n' "$extracted" | grep -Fq '/alpha'

    rtk --version | grep -Eq '^rtk [0-9]+\.[0-9]+\.[0-9]+'
    rtk -v init -g --codex --dry-run > "$TMPDIR/rtk-init-dry-run.txt"
    grep -Fq 'RTK.md' "$TMPDIR/rtk-init-dry-run.txt"
    grep -Fq 'AGENTS.md' "$TMPDIR/rtk-init-dry-run.txt"

    for command in python python3 python3.14; do
      test -x "${python}/bin/$command"
    done
    python -c 'import sys; assert sys.version_info[:2] == (3, 14)'

    test ! -e "$CODEX_HOME"
    test ! -e "$HOME/.cache/ax"
    touch "$out"
  ''
