{
  casks,
  customUserPreferences,
  homeConfiguration,
  lib,
  nixboxConfiguration,
  pkgs,
  scriptCommands,
  serverConfiguration,
}:

let
  aerospace = homeConfiguration.programs.aerospace;
  settings = aerospace.settings;
  configFile = homeConfiguration.home.file.".aerospace.toml".source;

  packageName = package: package.pname or (lib.getName package);
  packageCount =
    name: packages: builtins.length (builtins.filter (package: packageName package == name) packages);

  navigationPackages = builtins.filter (
    package: packageName package == "macos-keyboard-navigation"
  ) homeConfiguration.home.packages;
  navigationPackage = builtins.head navigationPackages;
  navigationStatePaths = builtins.filter (
    statePath: statePath.owner == "macos-keyboard-navigation reconcile workflow"
  ) homeConfiguration.sayori.statePaths;

  fixtureDefaults = pkgs.writeShellApplication {
    name = "keyboard-navigation-defaults-fixture";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      if [[ "$#" -lt 6 || "$1" != "write" || "$3" != "AppleSymbolicHotKeys" || "$4" != "-dict-add" ]]; then
        echo "unexpected defaults fixture invocation" >&2
        exit 64
      fi

      domain="$2"
      plist="$domain.plist"
      shift 4

      if [[ ! -f "$plist" || $(( $# % 2 )) -ne 0 ]]; then
        echo "invalid defaults fixture target or leaf pairs" >&2
        exit 1
      fi

      leaf="$(mktemp "''${TMPDIR:-/tmp}/keyboard-navigation-defaults.XXXXXX")"
      trap 'rm -f "$leaf"' EXIT

      while [[ "$#" -gt 0 ]]; do
        id="$1"
        xml="$2"
        shift 2
        printf '%s\n' "$xml" > "$leaf"
        json="$(/usr/bin/plutil -convert json -o - "$leaf")"
        key="AppleSymbolicHotKeys.$id"
        if /usr/bin/plutil -extract "$key" raw -o - "$plist" >/dev/null 2>&1; then
          /usr/bin/plutil -replace "$key" -json "$json" "$plist"
        else
          /usr/bin/plutil -insert "$key" -json "$json" "$plist"
        fi
      done
    '';
  };
  fixtureNavigationPackage =
    pkgs.callPackage ../../modules/capabilities/macos-keyboard-navigation/package.nix
      {
        defaultsBin = "${fixtureDefaults}/bin/keyboard-navigation-defaults-fixture";
      };
  faultDefaults = pkgs.writeShellApplication {
    name = "keyboard-navigation-defaults-partial-failure";
    text = ''
      if [[ "$#" -lt 6 ]]; then
        echo "partial-failure adapter requires at least one leaf pair" >&2
        exit 64
      fi
      "${fixtureDefaults}/bin/keyboard-navigation-defaults-fixture" \
        "$1" "$2" "$3" "$4" "$5" "$6"
      exit 75
    '';
  };
  faultNavigationPackage =
    pkgs.callPackage ../../modules/capabilities/macos-keyboard-navigation/package.nix
      {
        defaultsBin = "${faultDefaults}/bin/keyboard-navigation-defaults-partial-failure";
      };

  expectedMainBindings = {
    ctrl-left = "focus left";
    ctrl-down = "focus down";
    ctrl-up = "focus up";
    ctrl-right = "focus right";
    ctrl-1 = "workspace 1";
    ctrl-2 = "workspace 2";
    ctrl-3 = "workspace 3";
    ctrl-4 = "workspace 4";
    ctrl-5 = "workspace 5";
    ctrl-6 = "workspace 6";
    ctrl-7 = "workspace 7";
    ctrl-8 = "workspace 8";
    ctrl-9 = "workspace 9";
    ctrl-0 = "workspace 10";
    ctrl-shift-1 = "move-node-to-workspace 1";
    ctrl-shift-2 = "move-node-to-workspace 2";
    ctrl-shift-3 = "move-node-to-workspace 3";
    ctrl-shift-4 = "move-node-to-workspace 4";
    ctrl-shift-5 = "move-node-to-workspace 5";
    ctrl-shift-6 = "move-node-to-workspace 6";
    ctrl-shift-7 = "move-node-to-workspace 7";
    ctrl-shift-8 = "move-node-to-workspace 8";
    ctrl-shift-9 = "move-node-to-workspace 9";
    ctrl-shift-0 = "move-node-to-workspace 10";
    ctrl-v = "layout floating tiling";
    ctrl-esc = "enable off";
  };

  raycastCasks = lib.filter (cask: (cask.name or null) == "raycast") casks;
  entrypoints = [
    "bilibili-switch.sh"
    "chatgpt-switch.sh"
    "claude-switch.sh"
    "gemini-switch.sh"
    "github-switch.sh"
    "notebook-switch.sh"
    "youtube-switch.sh"
  ];
  iconFiles = [
    "icons/bilibili.png"
    "icons/chatgpt.png"
    "icons/claude.png"
    "icons/gemini-notebook-dark.png"
    "icons/gemini-notebook-light.png"
    "icons/gemini.png"
    "icons/github.png"
    "icons/youtube.png"
  ];
  supportFiles = [
    "chrome-switch.sh"
    "config/bilibili-switch.json"
    "config/chatgpt-switch.json"
    "config/claude-switch.json"
    "config/gemini-switch.json"
    "config/github-switch.json"
    "config/notebook-switch.json"
    "config/youtube-switch.json"
  ]
  ++ iconFiles
  ++ [
    "lib/chrome-switch.js"
  ];
  expectedFiles = entrypoints ++ supportFiles;
  retiredFiles = [
    "toggle-db-tunnel.sh"
    "yume-switch.sh"
    "config/yume-switch.json"
  ];

  nixboxHome = nixboxConfiguration.config.home-manager.users.sayori;
  serverHome = serverConfiguration.config.home-manager.users.sayori;
in
assert lib.assertMsg (
  builtins.length raycastCasks == 1
) "macbook must have exactly one Raycast Homebrew cask owner";
assert lib.assertMsg (
  !(customUserPreferences ? "com.apple.symbolichotkeys")
) "AppleSymbolicHotKeys must not be replaced through activation-time CustomUserPreferences";
assert lib.assertMsg aerospace.enable "macbook must enable the AeroSpace Home Manager program";
assert lib.assertMsg (
  aerospace.package == pkgs.aerospace
) "macbook must use the locked Nixpkgs AeroSpace package";
assert lib.assertMsg (
  packageCount "aerospace" homeConfiguration.home.packages == 1
) "macbook must have exactly one Nix-owned AeroSpace package";
assert lib.assertMsg (
  packageCount "aerospace" nixboxHome.home.packages == 0
  && packageCount "aerospace" serverHome.home.packages == 0
) "nixbox and server must not contain the AeroSpace package";
assert lib.assertMsg (
  !nixboxHome.programs.aerospace.enable && !serverHome.programs.aerospace.enable
) "nixbox and server must not enable AeroSpace";
assert lib.assertMsg (builtins.all (
  cask: (cask.name or null) != "aerospace"
) casks) "AeroSpace must not gain a competing Homebrew cask owner";
assert lib.assertMsg (
  builtins.length navigationPackages == 1
) "macbook must have exactly one macOS keyboard-navigation policy package";
assert lib.assertMsg (
  builtins.length navigationStatePaths == 1
  && (builtins.head navigationStatePaths).backup == "separate-policy"
) "macbook must declare the owner-only keyboard-navigation rollback receipt boundary";
assert lib.assertMsg (
  packageCount "macos-keyboard-navigation" nixboxHome.home.packages == 0
  && packageCount "macos-keyboard-navigation" serverHome.home.packages == 0
) "nixbox and server must not contain the macOS keyboard-navigation policy package";
assert lib.assertMsg (
  !aerospace.launchd.enable
) "AeroSpace must not create a Home Manager LaunchAgent";
assert lib.assertMsg (
  !homeConfiguration.launchd.agents.aerospace.enable
) "the generated AeroSpace LaunchAgent must remain disabled";
assert lib.assertMsg (
  settings."start-at-login" == false && settings."after-login-command" == [ ]
) "AeroSpace must remain manual-start only";
assert lib.assertMsg (
  settings."default-root-container-layout" == "tiles"
) "AeroSpace must default to automatic tiling";
assert lib.assertMsg (
  settings.mode.main.binding == expectedMainBindings
) "AeroSpace main-mode bindings must exactly match the approved bare-Control map";
assert lib.assertMsg (
  builtins.attrNames settings.mode == [ "main" ]
) "AeroSpace must not retain the superseded move mode";
assert lib.assertMsg (
  settings."on-window-detected" == [ ]
) "the first AeroSpace trial must not guess application exceptions";
assert lib.assertMsg (
  !(settings ? "workspace-to-monitor-force-assignment")
) "the first AeroSpace trial must preserve the existing monitor arrangement";
assert lib.assertMsg (
  !(settings ? "exec-on-workspace-change")
) "the first AeroSpace trial must not add workspace callbacks";
assert lib.assertMsg (
  !(lib.hasInfix "sketchybar" (lib.toLower (builtins.toJSON settings)))
) "the AeroSpace trial must not introduce SketchyBar integration";
pkgs.runCommand "macbook-keyboard-navigation-policy-check"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.file
      pkgs.findutils
      pkgs.gnugrep
      pkgs.jq
    ];
  }
  ''
    test -d "${pkgs.aerospace}/Applications/AeroSpace.app"
    test -x "${pkgs.aerospace}/Applications/AeroSpace.app/Contents/MacOS/AeroSpace"

    grep -Fqx 'after-login-command = []' "${configFile}"
    grep -Fqx 'start-at-login = false' "${configFile}"
    grep -Fqx '[mode.main.binding]' "${configFile}"
    grep -Fqx 'ctrl-esc = "enable off"' "${configFile}"
    grep -Fqx 'ctrl-left = "focus left"' "${configFile}"
    grep -Fqx 'ctrl-0 = "workspace 10"' "${configFile}"
    grep -Fqx 'ctrl-shift-0 = "move-node-to-workspace 10"' "${configFile}"
    grep -Fqx 'ctrl-v = "layout floating tiling"' "${configFile}"

    if grep -Eiq 'cmd-alt-ctrl|^\[mode\.move|workspace-to-monitor-force-assignment|exec-on-workspace-change|sketchybar' "${configFile}"; then
      echo 'AeroSpace config contains the superseded Hyper map or a forbidden callback' >&2
      exit 1
    fi

    ${lib.concatMapStringsSep "\n" (path: ''test -f "${scriptCommands}/${path}"'') expectedFiles}
    ${lib.concatMapStringsSep "\n" (path: ''test -x "${scriptCommands}/${path}"'') (
      entrypoints ++ [ "chrome-switch.sh" ]
    )}
    ${lib.concatMapStringsSep "\n" (path: ''test ! -e "${scriptCommands}/${path}"'') retiredFiles}

    ${lib.concatMapStringsSep "\n" (path: ''
      iconType="$(file -Lb "${scriptCommands}/${path}")"
      case "$iconType" in
        "PNG image data, 128 x 128"*) ;;
        *)
          echo "expected ${path} to be a 128 x 128 PNG, found: $iconType" >&2
          exit 1
          ;;
      esac
    '') iconFiles}

    grep -Fqx '# @raycast.icon icons/bilibili.png' "${scriptCommands}/bilibili-switch.sh"
    grep -Fqx '# @raycast.icon icons/chatgpt.png' "${scriptCommands}/chatgpt-switch.sh"
    grep -Fqx '# @raycast.icon icons/claude.png' "${scriptCommands}/claude-switch.sh"
    grep -Fqx '# @raycast.icon icons/gemini.png' "${scriptCommands}/gemini-switch.sh"
    grep -Fqx '# @raycast.icon icons/github.png' "${scriptCommands}/github-switch.sh"
    grep -Fqx '# @raycast.icon icons/gemini-notebook-light.png' "${scriptCommands}/notebook-switch.sh"
    grep -Fqx '# @raycast.iconDark icons/gemini-notebook-dark.png' "${scriptCommands}/notebook-switch.sh"
    grep -Fqx '# @raycast.icon icons/youtube.png' "${scriptCommands}/youtube-switch.sh"
    grep -Fqx '# @raycast.title Gemini Notebook (Switch or Open)' "${scriptCommands}/notebook-switch.sh"
    grep -Fq '"notebook.google.com"' "${scriptCommands}/config/notebook-switch.json"
    grep -Fq '"defaultURL": "https://notebook.google.com/"' "${scriptCommands}/config/notebook-switch.json"

    fileCount="$(find -L "${scriptCommands}" -type f | wc -l | tr -d '[:space:]')"
    if [ "$fileCount" -ne 24 ]; then
      echo "expected 24 Raycast Script Command files, found $fileCount" >&2
      exit 1
    fi

    hostNavigationTool="${navigationPackage}/bin/macos-keyboard-navigation"
    navigationTool="${fixtureNavigationPackage}/bin/macos-keyboard-navigation"
    test -x "$hostNavigationTool"
    test -x "$navigationTool"

    symbolicDomain="$TMPDIR/com.apple.symbolichotkeys-fixture"
    symbolicPlist="$symbolicDomain.plist"
    raycastPlist="$TMPDIR/com.raycast.macos-fixture.plist"
    stateDir="$TMPDIR/navigation-state"
    cp "${./fixtures/keyboard-navigation-symbolic.plist}" "$symbolicPlist"
    cp "$symbolicPlist" "$TMPDIR/symbolic-before.plist"
    cp "${./fixtures/keyboard-navigation-raycast.plist}" "$raycastPlist"
    cp "$raycastPlist" "$TMPDIR/raycast-before.plist"
    chmod u+w "$symbolicPlist" "$raycastPlist"

    export MACOS_KEYBOARD_NAVIGATION_SYMBOLIC_DOMAIN="$symbolicDomain"
    export MACOS_KEYBOARD_NAVIGATION_SYMBOLIC_PLIST="$symbolicPlist"
    export MACOS_KEYBOARD_NAVIGATION_RAYCAST_PLIST="$raycastPlist"
    export MACOS_KEYBOARD_NAVIGATION_STATE_DIR="$stateDir"
    export MACOS_KEYBOARD_NAVIGATION_SKIP_PROCESS_CHECK=1

    "$hostNavigationTool" policy > "$TMPDIR/policy.json"
    jq -e '
      .version == 1
      and .raycast.ownership == "ui-owned-human-gate"
      and .raycast.raycastGlobalHotkey == "Command-49"
      and .raycast.raycast_hyperKey_state == {
        "enabled": true,
        "includeShiftKey": false,
        "keyCode": 57
      }
      and .symbolicHotkeys.ownership == "managed-leaves"
      and .symbolicHotkeys.domain == "com.apple.symbolichotkeys"
      and .symbolicHotkeys.hotkey27.desired.value.parameters == [32, 49, 1835008]
      and (.symbolicHotkeys.hotkey27.acceptedBaselines | length) == 2
      and .symbolicHotkeys.requiredDisable == [32, 33, 64, 65, 79, 81, 118, 119]
      and .symbolicHotkeys.disableIfPresent == [120, 121, 122, 123, 124, 125, 126, 127]
      and ([27] + .symbolicHotkeys.requiredDisable + .symbolicHotkeys.disableIfPresent | sort)
        == [27, 32, 33, 64, 65, 79, 81, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127]
    ' "$TMPDIR/policy.json"

    set +e
    "$navigationTool" audit > "$TMPDIR/audit-before.txt"
    auditBeforeStatus=$?
    set -e
    test "$auditBeforeStatus" -eq 2

    mkdir -p "$stateDir"
    printf '%s\n' receipt-temp-sentinel > "$TMPDIR/receipt-temp-victim"
    ln -s "$TMPDIR/receipt-temp-victim" "$stateDir/.active.json.tmp"
    set +e
    "$navigationTool" reconcile
    receiptTempStatus=$?
    set -e
    test "$(<"$TMPDIR/receipt-temp-victim")" = receipt-temp-sentinel
    if [[ "$receiptTempStatus" -eq 1 ]]; then
      rm "$stateDir/.active.json.tmp"
      "$navigationTool" reconcile
    else
      test "$receiptTempStatus" -eq 0
    fi
    "$navigationTool" audit > "$TMPDIR/audit-after.txt"
    test -f "$stateDir/active.json"

    set +e
    "$navigationTool" reconcile > "$TMPDIR/reconcile-with-active-receipt.txt" 2>&1
    activeReceiptStatus=$?
    set -e
    test "$activeReceiptStatus" -eq 1

    cp "$stateDir/active.json" "$TMPDIR/active-valid.json"
    jq '.leaves[0].id = 999' "$stateDir/active.json" > "$stateDir/active-tampered.json"
    chmod 600 "$stateDir/active-tampered.json"
    mv "$stateDir/active-tampered.json" "$stateDir/active.json"
    tamperedReceiptBefore="$(/usr/bin/plutil -convert json -o - "$symbolicPlist" | jq -S -c .)"

    set +e
    "$navigationTool" rollback > "$TMPDIR/rollback-tampered-receipt.txt" 2>&1
    tamperedReceiptStatus=$?
    set -e
    test "$tamperedReceiptStatus" -eq 1
    test "$(/usr/bin/plutil -convert json -o - "$symbolicPlist" | jq -S -c .)" = "$tamperedReceiptBefore"
    cp "$TMPDIR/active-valid.json" "$stateDir/active.json"
    chmod 600 "$stateDir/active.json"

    /usr/bin/plutil -extract AppleSymbolicHotKeys.27 json -o "$TMPDIR/id-27.json" "$symbolicPlist"
    jq -e '.enabled == true and .value.type == "standard" and .value.parameters == [32, 49, 1835008]' "$TMPDIR/id-27.json"

    for id in 32 33 64 65 79 81 118 119 120; do
      /usr/bin/plutil -extract "AppleSymbolicHotKeys.$id" json -o "$TMPDIR/id-$id.json" "$symbolicPlist"
      jq -e '.enabled == false and (.enabled | type) == "boolean" and (.value.parameters | all(.[]; type == "number"))' "$TMPDIR/id-$id.json"
    done

    test "$(/usr/bin/plutil -extract AppleSymbolicHotKeys.999.value.type raw "$symbolicPlist")" = sentinel
    test "$(/usr/bin/plutil -extract UnrelatedTopLevel raw "$symbolicPlist")" = preserve-me
    test "$(/usr/bin/plutil -extract AppleSymbolicHotKeys.120.value.parameters.1 raw "$symbolicPlist")" = 20
    for id in 121 122 123 124 125 126 127; do
      if /usr/bin/plutil -extract "AppleSymbolicHotKeys.$id" raw "$symbolicPlist" >/dev/null 2>&1; then
        echo "optional absent symbolic hotkey $id must not be created" >&2
        exit 1
      fi
    done

    test "$(/usr/bin/plutil -convert json -o - "$raycastPlist" | jq -S -c .)" = "$(/usr/bin/plutil -convert json -o - "$TMPDIR/raycast-before.plist" | jq -S -c .)"

    /usr/bin/plutil -extract AppleSymbolicHotKeys.32 xml1 -o "$TMPDIR/id-32-after.plist" "$symbolicPlist"
    cp "$TMPDIR/id-32-after.plist" "$TMPDIR/id-32-third-state.plist"
    /usr/bin/plutil -replace enabled -string unexpected "$TMPDIR/id-32-third-state.plist"
    "${fixtureDefaults}/bin/keyboard-navigation-defaults-fixture" write "$symbolicDomain" AppleSymbolicHotKeys -dict-add 32 "$(<"$TMPDIR/id-32-third-state.plist")"
    thirdState="$(/usr/bin/plutil -convert json -o - "$symbolicPlist" | jq -S -c .)"

    set +e
    "$navigationTool" rollback > "$TMPDIR/rollback-third-state.txt" 2>&1
    rollbackThirdStateStatus=$?
    set -e
    test "$rollbackThirdStateStatus" -eq 1
    test -f "$stateDir/active.json"
    test "$(/usr/bin/plutil -convert json -o - "$symbolicPlist" | jq -S -c .)" = "$thirdState"

    "${fixtureDefaults}/bin/keyboard-navigation-defaults-fixture" write "$symbolicDomain" AppleSymbolicHotKeys -dict-add 32 "$(<"$TMPDIR/id-32-after.plist")"
    /usr/bin/plutil -extract AppleSymbolicHotKeys.32 xml1 -o "$TMPDIR/id-32-before.plist" "$TMPDIR/symbolic-before.plist"
    "${fixtureDefaults}/bin/keyboard-navigation-defaults-fixture" write "$symbolicDomain" AppleSymbolicHotKeys -dict-add 32 "$(<"$TMPDIR/id-32-before.plist")"

    "$navigationTool" rollback
    test ! -e "$stateDir/active.json"
    test -d "$stateDir/history"
    test "$(/usr/bin/plutil -convert json -o - "$symbolicPlist" | jq -S -c .)" = "$(/usr/bin/plutil -convert json -o - "$TMPDIR/symbolic-before.plist" | jq -S -c .)"

    set +e
    "$navigationTool" audit > "$TMPDIR/audit-rolled-back.txt"
    auditRollbackStatus=$?
    set -e
    test "$auditRollbackStatus" -eq 2

    unknownDomain="$TMPDIR/com.apple.symbolichotkeys-unknown"
    unknownPlist="$unknownDomain.plist"
    unknownState="$TMPDIR/navigation-state-unknown"
    cp "${./fixtures/keyboard-navigation-symbolic.plist}" "$unknownPlist"
    chmod u+w "$unknownPlist"
    /usr/bin/plutil -replace AppleSymbolicHotKeys.27.value.parameters.2 -integer 123 "$unknownPlist"
    unknownBefore="$(/usr/bin/plutil -convert json -o - "$unknownPlist" | jq -S -c .)"

    export MACOS_KEYBOARD_NAVIGATION_SYMBOLIC_DOMAIN="$unknownDomain"
    export MACOS_KEYBOARD_NAVIGATION_SYMBOLIC_PLIST="$unknownPlist"
    export MACOS_KEYBOARD_NAVIGATION_STATE_DIR="$unknownState"

    set +e
    "$navigationTool" reconcile > "$TMPDIR/reconcile-unknown.txt" 2>&1
    unknownStatus=$?
    set -e
    test "$unknownStatus" -eq 1
    test ! -e "$unknownState/active.json"
    test "$(/usr/bin/plutil -convert json -o - "$unknownPlist" | jq -S -c .)" = "$unknownBefore"

    faultDomain="$TMPDIR/com.apple.symbolichotkeys-partial-failure"
    faultPlist="$faultDomain.plist"
    faultState="$TMPDIR/navigation-state-partial-failure"
    cp "${./fixtures/keyboard-navigation-symbolic.plist}" "$faultPlist"
    cp "$faultPlist" "$TMPDIR/fault-before.plist"
    chmod u+w "$faultPlist"

    export MACOS_KEYBOARD_NAVIGATION_SYMBOLIC_DOMAIN="$faultDomain"
    export MACOS_KEYBOARD_NAVIGATION_SYMBOLIC_PLIST="$faultPlist"
    export MACOS_KEYBOARD_NAVIGATION_RAYCAST_PLIST="$raycastPlist"
    export MACOS_KEYBOARD_NAVIGATION_STATE_DIR="$faultState"

    faultNavigationTool="${faultNavigationPackage}/bin/macos-keyboard-navigation"
    set +e
    "$faultNavigationTool" reconcile > "$TMPDIR/reconcile-partial-failure.txt" 2>&1
    partialFailureStatus=$?
    set -e
    test "$partialFailureStatus" -eq 1
    test -f "$faultState/active.json"
    test "$(/usr/bin/plutil -extract AppleSymbolicHotKeys.27.value.parameters.2 raw "$faultPlist")" = 1835008
    test "$(/usr/bin/plutil -extract AppleSymbolicHotKeys.32.enabled raw "$faultPlist")" = true

    "$navigationTool" rollback
    test ! -e "$faultState/active.json"
    test "$(/usr/bin/plutil -convert json -o - "$faultPlist" | jq -S -c .)" = "$(/usr/bin/plutil -convert json -o - "$TMPDIR/fault-before.plist" | jq -S -c .)"

    gateDomain="$TMPDIR/com.apple.symbolichotkeys-raycast-gate"
    gatePlist="$gateDomain.plist"
    gateRaycastPlist="$TMPDIR/com.raycast.macos-gate-drift.plist"
    gateState="$TMPDIR/navigation-state-gate"
    cp "${./fixtures/keyboard-navigation-symbolic.plist}" "$gatePlist"
    cp "${./fixtures/keyboard-navigation-raycast.plist}" "$gateRaycastPlist"
    chmod u+w "$gatePlist" "$gateRaycastPlist"
    /usr/bin/plutil -replace raycast_hyperKey_state.includeShiftKey -bool true "$gateRaycastPlist"
    gateBefore="$(/usr/bin/plutil -convert json -o - "$gatePlist" | jq -S -c .)"

    export MACOS_KEYBOARD_NAVIGATION_SYMBOLIC_DOMAIN="$gateDomain"
    export MACOS_KEYBOARD_NAVIGATION_SYMBOLIC_PLIST="$gatePlist"
    export MACOS_KEYBOARD_NAVIGATION_RAYCAST_PLIST="$gateRaycastPlist"
    export MACOS_KEYBOARD_NAVIGATION_STATE_DIR="$gateState"

    set +e
    "$navigationTool" reconcile > "$TMPDIR/reconcile-raycast-gate.txt" 2>&1
    gateStatus=$?
    set -e
    test "$gateStatus" -eq 2
    test ! -e "$gateState/active.json"
    test "$(/usr/bin/plutil -convert json -o - "$gatePlist" | jq -S -c .)" = "$gateBefore"

    symbolicTypeDomain="$TMPDIR/com.apple.symbolichotkeys-wrong-type"
    symbolicTypePlist="$symbolicTypeDomain.plist"
    symbolicTypeState="$TMPDIR/navigation-state-symbolic-wrong-type"
    cp "${./fixtures/keyboard-navigation-symbolic.plist}" "$symbolicTypePlist"
    chmod u+w "$symbolicTypePlist"
    /usr/bin/plutil -replace AppleSymbolicHotKeys.32.enabled -string true "$symbolicTypePlist"
    symbolicTypeBefore="$(/usr/bin/plutil -convert json -o - "$symbolicTypePlist" | jq -S -c .)"

    export MACOS_KEYBOARD_NAVIGATION_SYMBOLIC_DOMAIN="$symbolicTypeDomain"
    export MACOS_KEYBOARD_NAVIGATION_SYMBOLIC_PLIST="$symbolicTypePlist"
    export MACOS_KEYBOARD_NAVIGATION_RAYCAST_PLIST="$raycastPlist"
    export MACOS_KEYBOARD_NAVIGATION_STATE_DIR="$symbolicTypeState"

    set +e
    "$navigationTool" reconcile > "$TMPDIR/reconcile-symbolic-wrong-type.txt" 2>&1
    symbolicTypeStatus=$?
    set -e
    test "$symbolicTypeStatus" -eq 1
    test ! -e "$symbolicTypeState/active.json"
    test "$(/usr/bin/plutil -convert json -o - "$symbolicTypePlist" | jq -S -c .)" = "$symbolicTypeBefore"

    raycastTypeDomain="$TMPDIR/com.apple.symbolichotkeys-raycast-wrong-type"
    raycastTypePlist="$raycastTypeDomain.plist"
    raycastTypePrefs="$TMPDIR/com.raycast.macos-wrong-type.plist"
    raycastTypeState="$TMPDIR/navigation-state-raycast-wrong-type"
    cp "${./fixtures/keyboard-navigation-symbolic.plist}" "$raycastTypePlist"
    cp "${./fixtures/keyboard-navigation-raycast.plist}" "$raycastTypePrefs"
    chmod u+w "$raycastTypePlist" "$raycastTypePrefs"
    /usr/bin/plutil -replace raycast_hyperKey_state.keyCode -string 57 "$raycastTypePrefs"
    raycastTypeBefore="$(/usr/bin/plutil -convert json -o - "$raycastTypePlist" | jq -S -c .)"

    export MACOS_KEYBOARD_NAVIGATION_SYMBOLIC_DOMAIN="$raycastTypeDomain"
    export MACOS_KEYBOARD_NAVIGATION_SYMBOLIC_PLIST="$raycastTypePlist"
    export MACOS_KEYBOARD_NAVIGATION_RAYCAST_PLIST="$raycastTypePrefs"
    export MACOS_KEYBOARD_NAVIGATION_STATE_DIR="$raycastTypeState"

    set +e
    "$navigationTool" reconcile > "$TMPDIR/reconcile-raycast-wrong-type.txt" 2>&1
    raycastTypeStatus=$?
    set -e
    test "$raycastTypeStatus" -eq 1
    test ! -e "$raycastTypeState/active.json"
    test "$(/usr/bin/plutil -convert json -o - "$raycastTypePlist" | jq -S -c .)" = "$raycastTypeBefore"

    mismatchDomain="$TMPDIR/com.apple.symbolichotkeys-mismatch-write"
    mismatchDomainPlist="$mismatchDomain.plist"
    mismatchReadPlist="$TMPDIR/com.apple.symbolichotkeys-mismatch-read.plist"
    mismatchState="$TMPDIR/navigation-state-mismatch"
    cp "${./fixtures/keyboard-navigation-symbolic.plist}" "$mismatchDomainPlist"
    cp "${./fixtures/keyboard-navigation-symbolic.plist}" "$mismatchReadPlist"
    chmod u+w "$mismatchDomainPlist" "$mismatchReadPlist"
    mismatchWriteBefore="$(/usr/bin/plutil -convert json -o - "$mismatchDomainPlist" | jq -S -c .)"
    mismatchReadBefore="$(/usr/bin/plutil -convert json -o - "$mismatchReadPlist" | jq -S -c .)"

    export MACOS_KEYBOARD_NAVIGATION_SYMBOLIC_DOMAIN="$mismatchDomain"
    export MACOS_KEYBOARD_NAVIGATION_SYMBOLIC_PLIST="$mismatchReadPlist"
    export MACOS_KEYBOARD_NAVIGATION_RAYCAST_PLIST="$raycastPlist"
    export MACOS_KEYBOARD_NAVIGATION_STATE_DIR="$mismatchState"

    set +e
    "$navigationTool" reconcile > "$TMPDIR/reconcile-target-mismatch.txt" 2>&1
    mismatchStatus=$?
    set -e
    test "$mismatchStatus" -eq 1
    test ! -e "$mismatchState/active.json"
    test "$(/usr/bin/plutil -convert json -o - "$mismatchDomainPlist" | jq -S -c .)" = "$mismatchWriteBefore"
    test "$(/usr/bin/plutil -convert json -o - "$mismatchReadPlist" | jq -S -c .)" = "$mismatchReadBefore"

    productionModeDomain="$TMPDIR/com.apple.symbolichotkeys-wrong-mode"
    productionModePlist="$productionModeDomain.plist"
    productionModeState="$TMPDIR/navigation-state-wrong-mode"
    cp "${./fixtures/keyboard-navigation-symbolic.plist}" "$productionModePlist"
    chmod u+w "$productionModePlist"
    productionModeBefore="$(/usr/bin/plutil -convert json -o - "$productionModePlist" | jq -S -c .)"

    export MACOS_KEYBOARD_NAVIGATION_SYMBOLIC_DOMAIN="$productionModeDomain"
    export MACOS_KEYBOARD_NAVIGATION_SYMBOLIC_PLIST="$productionModePlist"
    export MACOS_KEYBOARD_NAVIGATION_RAYCAST_PLIST="$raycastPlist"
    export MACOS_KEYBOARD_NAVIGATION_STATE_DIR="$productionModeState"

    set +e
    MACOS_KEYBOARD_NAVIGATION_SKIP_PROCESS_CHECK=0 "$navigationTool" reconcile > "$TMPDIR/reconcile-wrong-mode.txt" 2>&1
    productionModeStatus=$?
    set -e
    test "$productionModeStatus" -eq 1
    test ! -e "$productionModeState/active.json"
    test "$(/usr/bin/plutil -convert json -o - "$productionModePlist" | jq -S -c .)" = "$productionModeBefore"

    touch "$out"
  ''
