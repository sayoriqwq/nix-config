{
  lib,
  macbookConfiguration,
  nixboxConfiguration,
  pkgs,
  serverConfiguration,
  source,
  username,
  ...
}:

let
  config = nixboxConfiguration.config;
  home = config.home-manager.users.${username};
  macbookHome = macbookConfiguration.config.home-manager.users.${username};
  server = serverConfiguration.config;
  serverHome = server.home-manager.users.${username};

  target = "fcitx5/rime";
  targetRoot = ".local/share/${target}";
  rimeDataPackage = import ../../modules/capabilities/chinese-input/rime-data-package.nix {
    inherit (pkgs) lib;
    inherit pkgs;
  };
  rimeDataRoot = "${rimeDataPackage}/share/rime-data";
  expectedRimeAddon = pkgs.fcitx5-rime.override {
    rimeDataPkgs = [ rimeDataPackage ];
  };
  inputPackage = config.i18n.inputMethod.package;

  packageName = package: lib.toLower (package.pname or (lib.getName package));
  isInputPackage =
    package:
    let
      name = packageName package;
    in
    lib.hasInfix "fcitx" name || lib.hasInfix "rime" name || lib.hasInfix "ibus" name;
  isIbusPackage = package: lib.hasInfix "ibus" (packageName package);
  nixboxInputPackages =
    config.environment.defaultPackages
    ++ config.environment.systemPackages
    ++ home.home.packages
    ++ config.programs.dconf.packages
    ++ config.services.dbus.packages
    ++ config.xdg.portal.extraPortals;
  serverInputPackages =
    server.environment.defaultPackages
    ++ server.environment.systemPackages
    ++ serverHome.home.packages
    ++ server.programs.dconf.packages
    ++ server.services.dbus.packages
    ++ server.xdg.portal.extraPortals;

  expectedGlobalConfig = ''
    [Behavior]
    ActiveByDefault=True
    AllowInputMethodForPassword=False
    ShareInputState=All
    resetStateWhenFocusIn=No

    [Hotkey/AltTriggerKeys]

    [Hotkey/TriggerKeys]
  '';
  expectedProfile = ''
    [GroupOrder]
    0=Default

    [Groups/0]
    Default Layout=us
    DefaultIM=rime
    Name=Default

    [Groups/0/Items/0]
    Layout=us
    Name=rime
  '';
  expectedRimeConfig = ''
    InputState=All

  '';

  rimeHomeRoot = "${home.home.homeDirectory}/.local/share/fcitx5/rime";
  expectedStateContract = [
    {
      path = "${rimeHomeRoot}/build";
      backup = "excluded";
    }
    {
      path = "${rimeHomeRoot}/luna_pinyin.userdb";
      backup = "required";
    }
    {
      path = "${rimeHomeRoot}/rime_ice.userdb";
      backup = "required";
    }
    {
      path = "${rimeHomeRoot}/sync";
      backup = "separate-policy";
    }
    {
      path = "${rimeHomeRoot}/installation.yaml";
      backup = "required";
    }
    {
      path = "${rimeHomeRoot}/user.yaml";
      backup = "required";
    }
    {
      path = "${home.home.homeDirectory}/.config/fcitx5";
      backup = "required";
    }
  ];
  actualStateContract = lib.sort (left: right: left.path < right.path) (
    map
      (entry: {
        inherit (entry) path backup;
      })
      (
        builtins.filter (
          entry: entry.owner == "Rime" || entry.owner == "Fcitx5" || lib.hasInfix "/fcitx5" entry.path
        ) home.sayori.statePaths
      )
  );
  sortedExpectedStateContract = lib.sort (left: right: left.path < right.path) expectedStateContract;

  adapterResult = import ../../modules/capabilities/chinese-input/nixos.nix {
    inherit lib pkgs username;
  };
  adapterTopLevel = lib.sort lib.lessThan (builtins.attrNames adapterResult);
  inputUserServiceNames = builtins.filter (
    name:
    let
      normalized = lib.toLower name;
    in
    lib.hasInfix "fcitx" normalized || lib.hasInfix "ibus" normalized
  ) (builtins.attrNames home.systemd.user.services);
  serverInputUserServiceNames = builtins.filter (
    name:
    let
      normalized = lib.toLower name;
    in
    lib.hasInfix "fcitx" normalized || lib.hasInfix "ibus" normalized
  ) (builtins.attrNames serverHome.systemd.user.services);
  managedRimeTargets =
    candidateHome:
    builtins.filter (name: name == target || lib.hasPrefix "${target}/" name) (
      builtins.attrNames candidateHome.xdg.dataFile
    );

  combinedNixboxEnvironment =
    config.environment.variables // config.environment.sessionVariables // home.home.sessionVariables;
  combinedServerEnvironment =
    server.environment.variables
    // server.environment.sessionVariables
    // serverHome.home.sessionVariables;

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
in
assert lib.assertMsg
  (
    config.i18n.inputMethod.enable
    && config.i18n.inputMethod.type == "fcitx5"
    && lib.getVersion inputPackage == "5.1.19"
  )
  "nixbox Chinese input capability must replace IBus with the reviewed Fcitx 5.1.19 combined package";
assert lib.assertMsg
  (
    config.i18n.inputMethod.fcitx5.addons == [ expectedRimeAddon ]
    && lib.getVersion expectedRimeAddon == "5.1.13"
    && pkgs.rime-ice.version == "2026.06.30"
  )
  "nixbox must compose only fcitx5-rime 5.1.13 with the reviewed Linux rime-ice 2026.06.30 data package";
assert lib.assertMsg
  (
    !config.i18n.inputMethod.fcitx5.waylandFrontend
    && !config.i18n.inputMethod.fcitx5.ignoreUserConfig
    && combinedNixboxEnvironment.XMODIFIERS == "@im=fcitx"
    && combinedNixboxEnvironment.GTK_IM_MODULE == "fcitx"
    && combinedNixboxEnvironment.QT_IM_MODULE == "fcitx"
    && combinedNixboxEnvironment.QT_PLUGIN_PATH == "${inputPackage}/${pkgs.qt6.qtbase.qtPluginPrefix}"
  )
  "nixbox must expose the reviewed Fcitx Wayland/XWayland/GTK/Qt environment without disabling writable user configuration";
assert lib.assertMsg
  (
    config.environment.etc."xdg/fcitx5/config".text == expectedGlobalConfig
    && config.environment.etc."xdg/fcitx5/profile".text == expectedProfile
    && config.environment.etc."xdg/fcitx5/conf/rime.conf".text == expectedRimeConfig
  )
  "nixbox Fcitx system defaults must keep Rime active/shared with no framework triggers and no keyboard fallback";
assert lib.assertMsg
  (
    builtins.filter isIbusPackage nixboxInputPackages == [ ]
    && !lib.hasInfix "ibus" (lib.toLower (builtins.toJSON combinedNixboxEnvironment))
  )
  "nixbox must not retain an IBus package, portal, D-Bus owner, autostart entry, or session environment";
assert lib.assertMsg
  (
    home.xdg.dataFile.${target}.recursive
    && !home.xdg.dataFile.${target}.force
    && home.xdg.dataFile.${target}.target == targetRoot
    && toString home.xdg.dataFile.${target}.source == rimeDataRoot
  )
  "nixbox Home Manager must recursively project the shared Rime data package without replacing the writable user root";
assert lib.assertMsg (actualStateContract == sortedExpectedStateContract)
  "nixbox Chinese input capability must declare the exact seven writable Fcitx/Rime state boundaries";
assert lib.assertMsg (
  !home.i18n.inputMethod.enable
  && inputUserServiceNames == [ ]
  && !lib.hasInfix "fcitx" (lib.toLower home.xdg.configFile."hypr/hyprland.lua".text)
) "nixbox must not enable a second Home Manager package, daemon, or Hyprland exec-once owner";
assert lib.assertMsg
  (
    adapterTopLevel == [
      "home-manager"
      "i18n"
    ]
  )
  "the NixOS Chinese input adapter must not acquire unrelated service, network, firewall, or desktop ownership";
assert lib.assertMsg
  (
    builtins.hasAttr target macbookHome.xdg.dataFile
    && managedRimeTargets serverHome == [ ]
    && !server.i18n.inputMethod.enable
    && builtins.filter isInputPackage serverInputPackages == [ ]
    && serverInputUserServiceNames == [ ]
    && !(combinedServerEnvironment ? XMODIFIERS)
    && !(combinedServerEnvironment ? GTK_IM_MODULE)
    && !(combinedServerEnvironment ? QT_IM_MODULE)
    && !(combinedServerEnvironment ? QT_PLUGIN_PATH)
  )
  "macbook must share the Rime data contract while server inherits no input framework, package, projection, or environment";
assert lib.assertMsg (
  !(builtins.pathExists (source + "/modules/home/capabilities/macos-chinese-input"))
) "the retired macOS-only wrapper must not survive beside the shared cross-platform capability";
pkgs.runCommand "nixbox-chinese-input-policy-check"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.jq
      pkgs.librime
      pkgs.yq-go
    ];
  }
  ''
    set -euo pipefail

    test ${lib.escapeShellArg (builtins.elem inputPackage config.environment.systemPackages)} = 1
    test ${lib.escapeShellArg (builtins.elem "/etc/xdg" config.environment.pathsToLink)} = 1
    test -f ${inputPackage}/etc/xdg/autostart/org.fcitx.Fcitx5.desktop
    grep -Fx 'Exec=${inputPackage}/bin/fcitx5' \
      ${inputPackage}/etc/xdg/autostart/org.fcitx.Fcitx5.desktop >/dev/null
    ! test -e ${inputPackage}/etc/xdg/autostart/ibus-daemon.desktop
    test -x ${inputPackage}/bin/fcitx5
    test -x ${inputPackage}/bin/fcitx5-config-qt
    test -f ${inputPackage}/lib/fcitx5/rime.so

    test -f ${rimeDataRoot}/rime_ice_suggestion.yaml
    test -f ${rimeDataRoot}/default.custom.yaml
    ! test -e ${rimeDataRoot}/build
    test -f ${expectedRimeAddon}/share/rime-data/default.custom.yaml
    test -f ${inputPackage}/share/rime-data/default.custom.yaml

    ${pkgs.yq-go}/bin/yq eval -o=json ${rimeDataRoot}/default.custom.yaml \
      | ${pkgs.jq}/bin/jq -e \
        '.patch.__include == "rime_ice_suggestion:/"
         and .patch.schema_list == [{"schema": "rime_ice"}]
         and .patch."ascii_composer/switch_key/Shift_L" == "commit_code"
         and .patch."ascii_composer/switch_key/Shift_R" == "commit_code"' >/dev/null

    semantic_root="$TMPDIR/rime-overlay-semantics"
    mkdir -p "$semantic_root/user" "$semantic_root/shared" "$semantic_root/staging"
    install -m 0644 ${../../modules/capabilities/chinese-input/default.custom.yaml} \
      "$semantic_root/user/default.custom.yaml"
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

    touch "$out"
  ''
