{
  pkgs,
  lib,
  contract,
  rimeIceSource,
  source,
  preflight,
  behaviorReconciler,
  behaviorRollback,
  macbookConfiguration,
  nixboxConfiguration,
  serverConfiguration,
}:

let
  expectedRelease = "2025.04.06";
  expectedRevision = "a5f5404e369100fcfc5562f86f1205827453e31c";
  expectedNarHash = "sha256-s3r8cdEliiPnKWs64Wgi0rC9Ngl1mkIrLnr2tIcyXWw=";
  expectedManagedPathDigest = "82df5fa5c31bfffce7ca08b731b56c32106d78c2dc7459ea34dd6f95a7395de1";
  expectedStateBoundaryDigest = "5a1d16d1f347f51963c5e45cf7cf24deef06bdd0ca9a0144f650678fae20a8f8";
  expectedNetworkFirewallDigest = "674de3335869d227183a27491188df09681ba3517d875cf0cf1564b50bf6030e";
  username = "sayori";

  macbook = macbookConfiguration.config;
  macbookHome = macbook.home-manager.users.${username};
  nixboxHome = nixboxConfiguration.config.home-manager.users.${username};
  serverHome = serverConfiguration.config.home-manager.users.${username};

  dataRoot = lib.removePrefix ".local/share/" contract.targetRoot;
  upstreamTargets = map (path: "${dataRoot}/${path}") contract.managedPaths;
  localOverlayTarget = "${dataRoot}/default.custom.yaml";
  expectedTargets = upstreamTargets ++ [ localOverlayTarget ];
  managedTargetsFor =
    home:
    lib.filter (target: target == dataRoot || lib.hasPrefix "${dataRoot}/" target) (
      builtins.attrNames home.xdg.dataFile
    );
  macbookTargets = managedTargetsFor macbookHome;
  managedHomeTargetsFor =
    home:
    let
      relativeRoot = contract.targetRoot;
      absoluteRoot = "${home.home.homeDirectory}/${relativeRoot}";
    in
    lib.filter (
      target:
      target == relativeRoot
      || lib.hasPrefix "${relativeRoot}/" target
      || target == absoluteRoot
      || lib.hasPrefix "${absoluteRoot}/" target
    ) (builtins.attrNames home.home.file);
  expectedHomeTargets =
    map (path: "${macbookHome.home.homeDirectory}/${contract.targetRoot}/${path}") contract.managedPaths
    ++ [
      "${macbookHome.home.homeDirectory}/${contract.targetRoot}/${contract.localOverlay.relativePath}"
    ];

  expectedStatePaths = map (
    entry:
    (builtins.removeAttrs entry [ "relativePath" ])
    // {
      path = "${macbookHome.home.homeDirectory}/${entry.relativePath}";
    }
  ) contract.mutableStatePaths;
  stateRoot = macbookHome.home.homeDirectory;
  isChineseInputStatePath =
    entry:
    let
      path = entry.path;
      roots = [
        "${stateRoot}/${contract.targetRoot}"
        "${stateRoot}/.config/fcitx5"
        "${stateRoot}/${contract.behavior.journal.relativePath}"
        "${stateRoot}/Library/fcitx5"
        "${stateRoot}/Library/Caches/org.fcitx.inputmethod.Fcitx5"
      ];
    in
    lib.any (root: path == root || lib.hasPrefix "${root}/" path) roots;
  actualStatePaths = lib.filter (entry: isChineseInputStatePath entry) macbookHome.sayori.statePaths;
  sortStatePaths = builtins.sort (left: right: left.path < right.path);
  managedPathDigest = builtins.hashString "sha256" (
    builtins.toJSON (builtins.sort builtins.lessThan contract.managedPaths)
  );
  stateBoundaryDigest = builtins.hashString "sha256" (
    builtins.toJSON (
      builtins.sort (left: right: left.relativePath < right.relativePath) (
        map (entry: {
          inherit (entry) relativePath owner backup;
        }) contract.mutableStatePaths
      )
    )
  );

  forbiddenTargets = [
    dataRoot
    "${dataRoot}/.DS_Store"
    "${dataRoot}/build"
    "${dataRoot}/installation.yaml"
    "${dataRoot}/luna_pinyin.userdb"
    "${dataRoot}/rime_ice.userdb"
    "${dataRoot}/squirrel.custom.yaml"
    "${dataRoot}/sync"
    "${dataRoot}/user.yaml"
  ];
  isForbiddenTarget =
    target:
    target == dataRoot
    || lib.any (forbidden: target == forbidden || lib.hasPrefix "${forbidden}/" target) (
      lib.drop 1 forbiddenTargets
    );

  declarationName =
    declaration: lib.toLower (if builtins.isAttrs declaration then declaration.name else declaration);
  packageName = package: lib.toLower (package.pname or (lib.getName package));
  isChineseInputDependencyName =
    name:
    lib.hasInfix "fcitx" name || name == "rime" || name == "rime-ice" || lib.hasPrefix "librime" name;
  chineseInputHomePackages = lib.filter (
    package: isChineseInputDependencyName (packageName package)
  ) macbookHome.home.packages;
  chineseInputSystemPackages = lib.filter (
    package: isChineseInputDependencyName (packageName package)
  ) (macbook.environment.defaultPackages ++ macbook.environment.systemPackages);
  chineseInputBrews = lib.filter (
    brew: isChineseInputDependencyName (declarationName brew)
  ) macbook.homebrew.brews;
  chineseInputCasks = lib.filter (
    cask: isChineseInputDependencyName (declarationName cask)
  ) macbook.homebrew.casks;
  serviceOptionNames = builtins.attrNames macbook.services ++ builtins.attrNames macbookHome.services;
  chineseInputServiceOptions = lib.filter isChineseInputDependencyName serviceOptionNames;
  launchdDeclarations = {
    inherit (macbook.launchd) agents daemons;
    homeManagerAgents = macbookHome.launchd.agents;
    userAgents = macbook.launchd.user.agents;
  };
  launchdJSON = lib.toLower (builtins.toJSON launchdDeclarations);
  hasChineseInputLaunchdName = lib.any (name: lib.hasInfix name launchdJSON) [
    "fcitx"
    "librime"
    "rime-ice"
  ];
  networkFirewallContract = {
    inherit (macbook.networking)
      applicationFirewall
      dns
      domain
      hostName
      knownNetworkServices
      localHostName
      networkservices
      search
      wakeOnLan
      ;
    wgQuick = macbook.networking.wg-quick;
  };
  networkFirewallDigest = builtins.hashString "sha256" (builtins.toJSON networkFirewallContract);
  targetSourcesMatch = lib.all (
    path: toString macbookHome.xdg.dataFile."${dataRoot}/${path}".source == "${rimeIceSource}/${path}"
  ) contract.managedPaths;

  managedFcitxConfigTargetsFor =
    home:
    lib.filter (target: target == "fcitx5" || lib.hasPrefix "fcitx5/" target) (
      builtins.attrNames home.xdg.configFile
    );
  managedFcitxHomeTargetsFor =
    home:
    let
      relativeRoot = ".config/fcitx5";
      absoluteRoot = "${home.home.homeDirectory}/${relativeRoot}";
    in
    lib.filter (
      target:
      target == relativeRoot
      || lib.hasPrefix "${relativeRoot}/" target
      || target == absoluteRoot
      || lib.hasPrefix "${absoluteRoot}/" target
    ) (builtins.attrNames home.home.file);

  macbookBehaviorActivation = macbookHome.home.activation.reconcileFcitx5Behavior;

  exactManagedSet =
    paths:
    builtins.length paths == 65
    && builtins.sort builtins.lessThan paths == builtins.sort builtins.lessThan contract.managedPaths;
in
assert lib.assertMsg (
  pkgs.stdenv.hostPlatform.isDarwin && pkgs.stdenv.hostPlatform.system == "aarch64-darwin"
) "macbook Rime policy must remain guarded to the audited Apple Silicon Darwin host";
assert lib.assertMsg (
  contract.release == expectedRelease
) "Rime policy must preserve the reviewed 2025.04.06 release";
assert lib.assertMsg (
  contract.revision == expectedRevision
) "Rime policy must preserve the reviewed upstream revision";
assert lib.assertMsg (
  contract.narHash == expectedNarHash
) "Rime policy must preserve the reviewed source narHash";
assert lib.assertMsg (
  managedPathDigest == expectedManagedPathDigest
) "Rime policy must preserve the independently reviewed 65-path allowlist";
assert lib.assertMsg (
  stateBoundaryDigest == expectedStateBoundaryDigest
) "Rime policy must preserve the independently reviewed mutable-state ownership contract";
assert lib.assertMsg (lib.all (
  entry: entry.description != ""
) contract.mutableStatePaths) "every Rime/Fcitx mutable-state boundary must remain documented";
assert lib.assertMsg (
  contract.targetRoot == ".local/share/fcitx5/rime"
) "Rime policy target root must remain the fixed macbook Fcitx5 user-data path";
assert lib.assertMsg (
  contract.expectedManagedPathCount == 65
) "Rime policy must retain the reviewed static-leaf count";
assert lib.assertMsg (exactManagedSet contract.managedPaths)
  "macbook must manage exactly the 65 reviewed Rime source leaves";
assert lib.assertMsg (
  contract.localOverlay.relativePath == "default.custom.yaml"
  &&
    contract.localOverlay.sha256 == "6d68d560d1d46937ee5e9ac10b50498257d5e868aeb2be293581a00c73aa0a30"
  && builtins.hashFile "sha256" contract.localOverlay.source == contract.localOverlay.sha256
  &&
    builtins.readFile contract.localOverlay.source == ''
      patch:
        schema_list:
          - schema: rime_ice
    ''
  &&
    toString macbookHome.xdg.dataFile.${localOverlayTarget}.source
    == toString contract.localOverlay.source
) "macbook must add the approved local default.custom.yaml overlay beside the 65 upstream leaves";
assert lib.assertMsg (
  contract.behavior.desired.global.Behavior.ShareInputState == "All"
  && contract.behavior.desired.macosfrontend.AppDefaultIM == { }
  && contract.behavior.desired.macosfrontend.StatusBar == "Hidden"
  &&
    contract.behavior.keep.global.Hotkey.AltTriggerKeys == {
      "0" = "Shift+Shift_L";
      "1" = "Shift+Shift_R";
    }
  && !(contract.behavior.keep ? macosfrontend)
  && contract.behavior.keep.rime.InputState == "All"
) "macbook must preserve the approved Fcitx5 desired values and Keep-only invariants";
assert lib.assertMsg
  (builtins.sort builtins.lessThan macbookTargets == builtins.sort builtins.lessThan expectedTargets)
  "macbook final xdg.dataFile targets must contain 65 reviewed upstream leaves plus one local overlay";
assert lib.assertMsg targetSourcesMatch
  "every final macbook Rime target must source its corresponding pinned upstream leaf";
assert lib.assertMsg (
  builtins.sort builtins.lessThan (managedHomeTargetsFor macbookHome)
  == builtins.sort builtins.lessThan expectedHomeTargets
) "macbook final home.file expansion must manage only the 65 upstream leaves and one local overlay";
assert lib.assertMsg (
  managedTargetsFor nixboxHome == [ ] && managedHomeTargetsFor nixboxHome == [ ]
) "nixbox must not select the macOS Chinese input capability";
assert lib.assertMsg (
  managedTargetsFor serverHome == [ ] && managedHomeTargetsFor serverHome == [ ]
) "server must not select the macOS Chinese input capability";
assert lib.assertMsg (
  managedFcitxConfigTargetsFor macbookHome == [ ]
  && managedFcitxHomeTargetsFor macbookHome == [ ]
  && managedFcitxConfigTargetsFor nixboxHome == [ ]
  && managedFcitxHomeTargetsFor nixboxHome == [ ]
  && managedFcitxConfigTargetsFor serverHome == [ ]
  && managedFcitxHomeTargetsFor serverHome == [ ]
) "Fcitx5 writable configuration files must remain outside Store-managed file ownership";
assert lib.assertMsg (
  macbookBehaviorActivation.after == [ "writeBoundary" ]
  && macbookBehaviorActivation.before == [ ]
  && lib.hasInfix "/bin/fcitx5-behavior-reconciler reconcile" macbookBehaviorActivation.data
  && lib.hasInfix contract.behavior.journal.relativePath macbookBehaviorActivation.data
  && !(nixboxHome.home.activation ? reconcileFcitx5Behavior)
  && !(serverHome.home.activation ? reconcileFcitx5Behavior)
) "only macbook must reconcile the approved Fcitx5 behavior through the internal adapter";
assert lib.assertMsg (
  !(lib.any isForbiddenTarget (builtins.attrNames macbookHome.xdg.dataFile))
) "Rime root, mutable state, and Squirrel custom configuration must remain unmanaged";
assert lib.assertMsg (sortStatePaths actualStatePaths == sortStatePaths expectedStatePaths)
  "macbook final state-path declarations must preserve every reviewed Rime and Fcitx mutable boundary";
assert lib.assertMsg (
  chineseInputHomePackages == [ ] && chineseInputSystemPackages == [ ]
) "Fcitx5.app and its Rime plugin must not gain a Nix package owner";
assert lib.assertMsg (
  chineseInputBrews == [ ] && chineseInputCasks == [ ]
) "Fcitx5.app and its Rime plugin must not gain a Homebrew owner";
assert lib.assertMsg (
  !hasChineseInputLaunchdName
) "macOS Chinese input must not gain a hidden launchd owner";
assert lib.assertMsg (
  chineseInputServiceOptions == [ ]
) "macOS Chinese input must not gain a system or Home Manager service owner";
assert lib.assertMsg (
  networkFirewallDigest == expectedNetworkFirewallDigest
) "macOS Chinese input must preserve the reviewed network and firewall contract";
assert lib.assertMsg (
  !(contract.isSafeRelativePath "")
) "path policy must reject an empty managed path";
assert lib.assertMsg (
  !(contract.isSafeRelativePath "/absolute")
) "path policy must reject absolute managed paths";
assert lib.assertMsg (
  !(contract.isSafeRelativePath "../escape")
) "path policy must reject parent-directory escapes";
assert lib.assertMsg (
  !(contract.isSafeRelativePath "dir//leaf")
) "path policy must reject empty path components";
assert lib.assertMsg (contract.isForbiddenManagedPath "safe.userdb/entry")
  "path policy must reject user databases";
assert lib.assertMsg (contract.isForbiddenManagedPath "build/generated.yaml")
  "path policy must reject the Rime build tree";
assert lib.assertMsg (contract.isForbiddenManagedPath "sync/export.yaml")
  "path policy must reject the Rime sync tree";
assert lib.assertMsg (contract.isForbiddenManagedPath "installation.yaml")
  "path policy must reject Rime installation identity";
assert lib.assertMsg (contract.isForbiddenManagedPath "user.yaml")
  "path policy must reject Rime runtime state";
assert lib.assertMsg (contract.isForbiddenManagedPath ".DS_Store")
  "path policy must reject Finder metadata";
assert lib.assertMsg (contract.isForbiddenManagedPath "squirrel.custom.yaml")
  "path policy must reject the Squirrel-only patch";
assert lib.assertMsg (
  !(exactManagedSet (lib.drop 1 contract.managedPaths))
) "managed-set policy must fail closed when a reviewed source leaf is missing";
assert lib.assertMsg (
  !(exactManagedSet (contract.managedPaths ++ [ "unexpected.yaml" ]))
) "managed-set policy must fail closed when an extra source leaf is added";
pkgs.runCommand "macbook-rime-policy"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.jq
      preflight
      behaviorReconciler
      behaviorRollback
    ];
  }
  ''
    set -euo pipefail

    lock_file=${source}/flake.lock
    input_node="$(jq -r '.nodes.root.inputs["rime-ice"] // empty' "$lock_file")"
    test -n "$input_node"
    test "$(jq -r --arg node "$input_node" '.nodes[$node].flake' "$lock_file")" = false
    test "$(jq -r --arg node "$input_node" '.nodes[$node].locked.owner' "$lock_file")" = iDvel
    test "$(jq -r --arg node "$input_node" '.nodes[$node].locked.repo' "$lock_file")" = rime-ice
    test "$(jq -r --arg node "$input_node" '.nodes[$node].locked.rev' "$lock_file")" = ${lib.escapeShellArg expectedRevision}
    test "$(jq -r --arg node "$input_node" '.nodes[$node].locked.narHash' "$lock_file")" = ${lib.escapeShellArg expectedNarHash}
    test "$(jq -r --arg node "$input_node" '.nodes[$node].original.owner' "$lock_file")" = iDvel
    test "$(jq -r --arg node "$input_node" '.nodes[$node].original.repo' "$lock_file")" = rime-ice
    test "$(jq -r --arg node "$input_node" '.nodes[$node].original.rev' "$lock_file")" = ${lib.escapeShellArg expectedRevision}

    validate_source_leaf() {
      source_root="$1"
      relative_path="$2"
      source_leaf="$source_root/$relative_path"

      test -f "$source_leaf" || return 1
      ! test -L "$source_leaf" || return 1

      source_root_real="$(realpath "$source_root")"
      source_real="$(realpath "$source_leaf")"
      case "$source_real" in
        "$source_root_real"/*) return 0 ;;
        *) return 1 ;;
      esac
    }

    source_root=${lib.escapeShellArg (toString rimeIceSource)}
    ${lib.concatMapStringsSep "\n" (
      path: "validate_source_leaf \"$source_root\" ${lib.escapeShellArg path}"
    ) contract.managedPaths}

    fixture="$TMPDIR/source-fixture"
    mkdir -p "$fixture/root"
    printf '%s\n' safe > "$fixture/root/regular"
    printf '%s\n' outside > "$fixture/outside"
    ln -s "$fixture/outside" "$fixture/root/escape"

    validate_source_leaf "$fixture/root" regular
    if validate_source_leaf "$fixture/root" missing; then
      echo "source policy accepted a missing leaf" >&2
      exit 1
    fi
    if validate_source_leaf "$fixture/root" escape; then
      echo "source policy accepted a symlink escape" >&2
      exit 1
    fi

    # Merely depending on the package builds the fixed-target preflight. The
    # policy check must never execute it against the maintainer's live files.
    test -x ${preflight}/bin/macbook-rime-preflight
    test -x ${behaviorReconciler}/bin/fcitx5-behavior-reconciler
    test -x ${behaviorRollback}/bin/macbook-fcitx5-behavior-rollback

    rollback_command='nix run .#macbook-fcitx5-behavior-rollback -- --confirm-approved-behavior-rollback'
    grep -F -- "$rollback_command" ${source}/docs/runbooks/restore-macos-environment.md >/dev/null
    grep -F -- "$rollback_command" ${source}/docs/plans/macos-chinese-input-stability-research.md >/dev/null
    if grep -F -- 'nix run path:.#macbook-fcitx5-behavior-rollback' \
      ${source}/docs/runbooks/restore-macos-environment.md \
      ${source}/docs/plans/macos-chinese-input-stability-research.md >/dev/null; then
      echo "behavior rollback documentation must preserve Git revision metadata" >&2
      exit 1
    fi

    touch "$out"
  ''
