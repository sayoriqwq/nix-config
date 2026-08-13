{
  casks,
  homeConfiguration,
  nixboxConfiguration,
  pkgs,
  serverConfiguration,
}:

let
  inherit (pkgs) lib;

  aerospace = homeConfiguration.programs.aerospace;
  settings = aerospace.settings;
  configFile = homeConfiguration.home.file.".aerospace.toml".source;

  packageName = package: package.pname or (lib.getName package);
  packageCount =
    name: packages: builtins.length (builtins.filter (package: packageName package == name) packages);

  expectedMainBindings = {
    cmd-alt-ctrl-left = "focus left";
    cmd-alt-ctrl-down = "focus down";
    cmd-alt-ctrl-up = "focus up";
    cmd-alt-ctrl-right = "focus right";
    cmd-alt-ctrl-1 = "workspace 1";
    cmd-alt-ctrl-2 = "workspace 2";
    cmd-alt-ctrl-3 = "workspace 3";
    cmd-alt-ctrl-4 = "workspace 4";
    cmd-alt-ctrl-5 = "workspace 5";
    cmd-alt-ctrl-6 = "workspace 6";
    cmd-alt-ctrl-7 = "workspace 7";
    cmd-alt-ctrl-8 = "workspace 8";
    cmd-alt-ctrl-9 = "workspace 9";
    cmd-alt-ctrl-0 = "workspace 10";
    cmd-alt-ctrl-shift-1 = "move-node-to-workspace 1";
    cmd-alt-ctrl-shift-2 = "move-node-to-workspace 2";
    cmd-alt-ctrl-shift-3 = "move-node-to-workspace 3";
    cmd-alt-ctrl-shift-4 = "move-node-to-workspace 4";
    cmd-alt-ctrl-shift-5 = "move-node-to-workspace 5";
    cmd-alt-ctrl-shift-6 = "move-node-to-workspace 6";
    cmd-alt-ctrl-shift-7 = "move-node-to-workspace 7";
    cmd-alt-ctrl-shift-8 = "move-node-to-workspace 8";
    cmd-alt-ctrl-shift-9 = "move-node-to-workspace 9";
    cmd-alt-ctrl-shift-0 = "move-node-to-workspace 10";
    cmd-alt-ctrl-f = "layout floating tiling";
    cmd-alt-ctrl-esc = "enable off";
  };

  nixboxHome = nixboxConfiguration.config.home-manager.users.sayori;
  serverHome = serverConfiguration.config.home-manager.users.sayori;
in
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
  !aerospace.launchd.enable
) "the first AeroSpace trial must not create a Home Manager LaunchAgent";
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
) "AeroSpace main-mode bindings must exactly match the approved Hyper map";
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
pkgs.runCommand "macbook-aerospace-policy-check"
  {
    nativeBuildInputs = [ pkgs.gnugrep ];
  }
  ''
    test -d "${pkgs.aerospace}/Applications/AeroSpace.app"
    test -x "${pkgs.aerospace}/Applications/AeroSpace.app/Contents/MacOS/AeroSpace"

    grep -Fqx 'after-login-command = []' "${configFile}"
    grep -Fqx 'start-at-login = false' "${configFile}"
    grep -Fqx '[mode.main.binding]' "${configFile}"
    grep -Fqx 'cmd-alt-ctrl-esc = "enable off"' "${configFile}"
    grep -Fqx 'cmd-alt-ctrl-left = "focus left"' "${configFile}"
    grep -Fqx 'cmd-alt-ctrl-0 = "workspace 10"' "${configFile}"
    grep -Fqx 'cmd-alt-ctrl-shift-0 = "move-node-to-workspace 10"' "${configFile}"
    grep -Fqx 'cmd-alt-ctrl-f = "layout floating tiling"' "${configFile}"

    if grep -Eiq '^\[mode\.move|workspace-to-monitor-force-assignment|exec-on-workspace-change|sketchybar' "${configFile}"; then
      echo 'AeroSpace config contains the retired move mode or a forbidden callback' >&2
      exit 1
    fi

    touch "$out"
  ''
