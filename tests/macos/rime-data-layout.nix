{
  lib,
  pkgs,
  flakeInputs,
  flakeOutputs,
  macbookConfiguration,
  nixboxConfiguration,
  serverConfiguration,
}:

let
  username = "sayori";
  target = "fcitx5/rime";
  targetRoot = ".local/share/${target}";
  overlay = ../../modules/home/capabilities/macos-chinese-input/default.custom.yaml;
  makeDataView = import ../../modules/home/capabilities/macos-chinese-input/rime-data-view.nix;
  productionView = makeDataView { inherit lib pkgs; };
  semanticSharedDefault = pkgs.writeText "default.yaml" ''
    config_version: "fixture"
    schema_list:
      - schema: obsolete
  '';
  semanticSuggestion = pkgs.writeText "rime_ice_suggestion.yaml" ''
    config_version: "suggestion-fixture"
    fixture_include_marker: loaded
    ascii_composer:
      switch_key:
        Shift_L: commit_code
        Shift_R: noop
    schema_list:
      - schema: obsolete
  '';
  semanticSchema = pkgs.writeText "rime_ice.schema.yaml" ''
    schema:
      schema_id: rime_ice
      name: Rime Ice Fixture
      version: "1"
    engine:
      processors: []
      segmentors: []
      translators: []
      filters: []
  '';
  capabilityResult = import ../../modules/home/capabilities/macos-chinese-input/default.nix {
    config.home.homeDirectory = "/fixture";
    inherit lib pkgs;
  };

  homeFor = configuration: configuration.config.home-manager.users.${username};
  macbook = macbookConfiguration.config;
  macbookHome = homeFor macbookConfiguration;
  nixboxHome = homeFor nixboxConfiguration;
  serverHome = homeFor serverConfiguration;
  managedRimeTargets =
    home:
    lib.filter (name: name == target || lib.hasPrefix "${target}/" name) (
      builtins.attrNames home.xdg.dataFile
    );

  fixturePackage =
    name: command:
    pkgs.runCommand name
      {
        pname = name;
        version = "1";
      }
      ''
        mkdir -p "$out/share/rime-data"
        ${command}
      '';
  safePackage = fixturePackage "rime-data-safe-fixture" ''
    mkdir -p "$out/share/rime-data/build" "$out/share/rime-data/nested"
    touch "$out/share/rime-data/build/.gitkeep"
    printf '%s\n' opaque > "$out/share/rime-data/build/user.yaml"
    ln -s user.yaml "$out/share/rime-data/build/runtime-link"
    printf '%s\n' static > "$out/share/rime-data/nested/static.yaml"
    printf '%s\n' suggestion > "$out/share/rime-data/rime_ice_suggestion.yaml"
  '';
  safeView = makeDataView {
    inherit lib overlay pkgs;
    rimeDataPackage = safePackage;
  };

  forbiddenFixturePaths = [
    {
      path = ".DS_Store";
      reportedPath = ".DS_Store";
    }
    {
      path = "installation.yaml";
      reportedPath = "installation.yaml";
    }
    {
      path = "squirrel.custom.yaml";
      reportedPath = "squirrel.custom.yaml";
    }
    {
      path = "sync/export.yaml";
      reportedPath = "sync";
    }
    {
      path = "user.yaml";
      reportedPath = "user.yaml";
    }
    {
      path = "cache.userdb/entry";
      reportedPath = "cache.userdb";
    }
  ];
  forbiddenFixtures = map (
    entry:
    let
      fixture = fixturePackage "rime-data-forbidden-fixture" ''
        mkdir -p "$out/share/rime-data/$(dirname ${lib.escapeShellArg entry.path})"
        touch "$out/share/rime-data/${entry.path}"
      '';
    in
    {
      root = "${fixture}/share/rime-data";
      expectedError = "rime-data-validator: forbidden mutable path: ${entry.reportedPath}";
    }
  ) forbiddenFixturePaths;
  collisionPackage = fixturePackage "rime-data-overlay-collision-fixture" ''
    touch "$out/share/rime-data/default.custom.yaml"
  '';
  symlinkPackage = fixturePackage "rime-data-symlink-fixture" ''
    printf '%s\n' static > "$out/share/rime-data/static.yaml"
    ln -s static.yaml "$out/share/rime-data/alias.yaml"
  '';
  missingRootPackage = pkgs.runCommand "rime-data-missing-root-fixture" { } ''
    mkdir -p "$out"
  '';
  validationFailures = forbiddenFixtures ++ [
    {
      root = "${missingRootPackage}/share/rime-data";
      expectedError = "rime-data-validator: data root is not a directory";
    }
    {
      root = "${collisionPackage}/share/rime-data";
      expectedError = "rime-data-validator: overlay collision: default.custom.yaml";
    }
    {
      root = "${symlinkPackage}/share/rime-data";
      expectedError = "rime-data-validator: unsupported symbolic link: alias.yaml";
    }
  ];

  macbookRimeDeclaration = macbookHome.xdg.dataFile.${target};
  recursiveLndirFlags = lib.optionalString macbookRimeDeclaration.ignorelinks "-ignorelinks";
  checkLinkTargetsScript = pkgs.writeShellScript "check-rime-link-targets" (
    macbookHome.home.activation.checkLinkTargets.data
  );
  packageName = package: lib.toLower (package.pname or (lib.getName package));
  declarationName =
    declaration: lib.toLower (if builtins.isAttrs declaration then declaration.name else declaration);
  isChineseInputName =
    name:
    lib.hasInfix "fcitx" name || name == "rime" || name == "rime-ice" || lib.hasPrefix "librime" name;
  chineseInputHomePackages = lib.filter (
    package: isChineseInputName (packageName package)
  ) macbookHome.home.packages;
  chineseInputSystemPackages = lib.filter (package: isChineseInputName (packageName package)) (
    macbook.environment.defaultPackages ++ macbook.environment.systemPackages
  );
  chineseInputBrews = lib.filter (
    declaration: isChineseInputName (declarationName declaration)
  ) macbook.homebrew.brews;
  chineseInputCasks = lib.filter (
    declaration: isChineseInputName (declarationName declaration)
  ) macbook.homebrew.casks;
  chineseInputServiceNames = lib.filter isChineseInputName (
    builtins.attrNames macbook.services ++ builtins.attrNames macbookHome.services
  );
  launchdAndNetworkJSON = lib.toLower (
    builtins.toJSON {
      inherit (macbook) launchd;
      homeLaunchd = macbookHome.launchd;
      networking = {
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
    }
  );
  behaviorJournalPaths = lib.filter (
    entry: lib.hasInfix "/.local/state/nix-config/macos-chinese-input/fcitx5-behavior" entry.path
  ) macbookHome.sayori.statePaths;
  darwinPackages = flakeOutputs.packages.aarch64-darwin;
  darwinApps = flakeOutputs.apps.aarch64-darwin or { };
in
assert lib.assertMsg (
  pkgs.stdenv.hostPlatform.system == "aarch64-darwin"
) "Rime data layout check must use the macbook Darwin package set";
assert lib.assertMsg (
  pkgs.rime-ice.version == "2026.06.30"
) "macbook must consume the approved rime-ice 2026.06.30 nixpkgs package";
assert lib.assertMsg (
  !(builtins.hasAttr "rime-ice" flakeInputs)
) "rime-ice must not remain an independent Flake input";
assert lib.assertMsg
  (
    !(capabilityResult ? home)
    && !(capabilityResult ? services)
    && !(capabilityResult ? launchd)
    && !(capabilityResult ? networking)
  )
  "macOS Chinese input must not declare packages, activation, services, launchd jobs, or networking";
assert lib.assertMsg (
  macbookRimeDeclaration.recursive
  && !macbookRimeDeclaration.force
  && macbookRimeDeclaration.target == targetRoot
  && toString macbookRimeDeclaration.source == toString productionView
) "macbook must recursively project one data view without replacing the writable target root";
assert lib.assertMsg (
  managedRimeTargets macbookHome == [ target ]
) "macbook must manage one recursive Rime data-view target rather than an upstream leaf manifest";
assert lib.assertMsg (
  managedRimeTargets nixboxHome == [ ] && managedRimeTargets serverHome == [ ]
) "nixbox and server must not select the macOS Chinese input capability";
assert lib.assertMsg (
  !(macbookHome.home.activation ? reconcileFcitx5Behavior)
) "macOS Chinese input must not retain an activation-time Fcitx behavior provider";
assert lib.assertMsg (
  behaviorJournalPaths == [ ]
) "macOS Chinese input must not retain a behavior-journal state-path declaration";
assert lib.assertMsg (
  !(darwinPackages ? macbook-fcitx5-behavior-rollback)
  && !(darwinPackages ? macbook-rime-preflight)
  && !(darwinApps ? macbook-fcitx5-behavior-rollback)
  && !(darwinApps ? macbook-rime-preflight)
) "retired Fcitx rollback and Rime runtime-preflight outputs must stay absent";
assert lib.assertMsg (
  chineseInputHomePackages == [ ]
  && chineseInputSystemPackages == [ ]
  && chineseInputBrews == [ ]
  && chineseInputCasks == [ ]
) "Fcitx5.app, its Rime plugin, and Rime engines must remain externally packaged";
assert lib.assertMsg (
  chineseInputServiceNames == [ ]
  && !(lib.hasInfix "fcitx" launchdAndNetworkJSON)
  && !(lib.hasInfix "rime" launchdAndNetworkJSON)
) "macOS Chinese input must not add service, launchd, firewall, or network ownership";
pkgs.runCommand "macbook-rime-data-layout"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.jq
      pkgs.librime
      pkgs.lndir
      pkgs.yq-go
    ];
  }
  ''
    set -euo pipefail

    test -f ${productionView}/rime_ice_suggestion.yaml
    test -f ${productionView}/default.custom.yaml
    ! test -e ${productionView}/build

    ${pkgs.yq-go}/bin/yq eval -o=json ${productionView}/default.custom.yaml \
      | ${pkgs.jq}/bin/jq -e \
        '.patch.__include == "rime_ice_suggestion:/"
         and .patch.schema_list == [{"schema": "rime_ice"}]
         and .patch."ascii_composer/switch_key/Shift_L" == "commit_code"
         and .patch."ascii_composer/switch_key/Shift_R" == "commit_code"' >/dev/null

    semantic_root="$TMPDIR/rime-overlay-semantics"
    mkdir -p "$semantic_root/user" "$semantic_root/shared" "$semantic_root/staging"
    install -m 0644 ${overlay} "$semantic_root/user/default.custom.yaml"
    install -m 0644 ${semanticSuggestion} "$semantic_root/user/rime_ice_suggestion.yaml"
    install -m 0644 ${semanticSchema} "$semantic_root/user/rime_ice.schema.yaml"
    install -m 0644 ${semanticSharedDefault} "$semantic_root/shared/default.yaml"
    ${pkgs.librime}/bin/rime_deployer --build \
      "$semantic_root/user" \
      "$semantic_root/shared" \
      "$semantic_root/staging"
    test -f "$semantic_root/staging/default.yaml"
    ${pkgs.yq-go}/bin/yq eval -o=json "$semantic_root/staging/default.yaml" \
      | ${pkgs.jq}/bin/jq -e \
        '.fixture_include_marker == "loaded"
         and (.schema_list | length) == 1
         and .schema_list[0].schema == "rime_ice"
         and .ascii_composer.switch_key.Shift_L == "commit_code"
         and .ascii_composer.switch_key.Shift_R == "commit_code"' >/dev/null

    test -f ${safeView}/nested/static.yaml
    test -f ${safeView}/default.custom.yaml
    ! test -e ${safeView}/build

    expect_validation_failure() {
      local root="$1"
      local expected_error="$2"
      local error_log="$TMPDIR/validator-error-$RANDOM"
      if ${lib.getExe productionView.validator} "$root" 2>"$error_log"; then
        echo "Rime data validator accepted a forbidden fixture" >&2
        exit 1
      fi
      test "$(cat "$error_log")" = "$expected_error"
    }
    ${lib.concatMapStringsSep "\n" (fixture: ''
      expect_validation_failure \
        ${lib.escapeShellArg fixture.root} \
        ${lib.escapeShellArg fixture.expectedError}
    '') validationFailures}

    new_generation="$TMPDIR/new-generation"
    generation_target="$new_generation/home-files/${targetRoot}"
    mkdir -p "$generation_target"
    ${pkgs.lndir}/bin/lndir -silent ${recursiveLndirFlags} ${safeView} "$generation_target"

    collision_home="$TMPDIR/collision-home"
    collision_target="$collision_home/${targetRoot}/nested/static.yaml"
    mkdir -p "$(dirname "$collision_target")"
    printf '%s\n' existing > "$collision_target"
    if env \
      HOME="$collision_home" \
      HOME_MANAGER_BACKUP_COMMAND= \
      HOME_MANAGER_BACKUP_EXT= \
      HOME_MANAGER_BACKUP_OVERWRITE= \
      newGenPath="$new_generation" \
      ${checkLinkTargetsScript} \
      >"$TMPDIR/check-link-targets.log" 2>&1; then
      echo "Home Manager accepted a conflicting regular Rime leaf" >&2
      exit 1
    fi
    grep -F \
      "Existing file '$collision_target' would be clobbered" \
      "$TMPDIR/check-link-targets.log" >/dev/null
    test "$(cat "$collision_target")" = existing
    ! test -L "$collision_target"

    fixture_home="$TMPDIR/home"
    target_root="$fixture_home/${targetRoot}"
    mkdir -p \
      "$target_root/build" \
      "$target_root/cache.userdb" \
      "$target_root/sync"
    printf '%s\n' mutable > "$target_root/build/runtime.yaml"
    printf '%s\n' mutable > "$target_root/cache.userdb/entry"
    printf '%s\n' mutable > "$target_root/installation.yaml"
    printf '%s\n' mutable > "$target_root/user.yaml"

    env \
      HOME="$fixture_home" \
      HOME_MANAGER_BACKUP_COMMAND= \
      HOME_MANAGER_BACKUP_EXT= \
      HOME_MANAGER_BACKUP_OVERWRITE= \
      newGenPath="$new_generation" \
      ${checkLinkTargetsScript}
    ${pkgs.lndir}/bin/lndir -silent ${recursiveLndirFlags} ${safeView} "$target_root"

    test -d "$target_root"
    ! test -L "$target_root"
    test -L "$target_root/nested/static.yaml"
    test -f "$target_root/build/runtime.yaml"
    ! test -L "$target_root/build/runtime.yaml"
    test -f "$target_root/cache.userdb/entry"
    ! test -L "$target_root/cache.userdb/entry"
    test -f "$target_root/installation.yaml"
    ! test -L "$target_root/installation.yaml"
    test -f "$target_root/user.yaml"
    ! test -L "$target_root/user.yaml"

    touch "$out"
  ''
