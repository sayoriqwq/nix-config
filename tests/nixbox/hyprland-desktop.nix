{
  lib,
  nixboxConfiguration,
  pkgs,
  username,
}:

let
  config = nixboxConfiguration.config;
  home = config.home-manager.users.${username};

  packageName = package: package.pname or (lib.getName package);
  packageCount =
    name: packages: builtins.length (builtins.filter (package: packageName package == name) packages);

  statePathCount =
    owner: builtins.length (builtins.filter (entry: entry.owner == owner) home.sayori.statePaths);

  desktopPortalNames = lib.sort lib.lessThan (
    map packageName (
      builtins.filter (
        package: lib.hasPrefix "xdg-desktop-portal-" (packageName package)
      ) config.xdg.portal.extraPortals
    )
  );

  displaySessionPackageNames = lib.sort lib.lessThan (
    map packageName config.services.displayManager.sessionPackages
  );

  gnomeDconfKeys = builtins.filter (name: lib.hasPrefix "org/gnome/" name) (
    builtins.attrNames home.dconf.settings
  );

  hyprlandConfig = pkgs.writeText "nixbox-hyprland.lua" home.xdg.configFile."hypr/hyprland.lua".text;

  combinedSessionEnvironment =
    config.environment.variables // config.environment.sessionVariables // home.home.sessionVariables;

  forbiddenGpuEnvironment = lib.filterAttrs (
    name: _:
    builtins.elem name [
      "AQ_DRM_DEVICES"
      "AQ_MGPU_NO_EXPLICIT"
      "AQ_NO_MODIFIERS"
      "GBM_BACKEND"
      "LIBVA_DRIVER_NAME"
      "MOZ_DISABLE_RDD_SANDBOX"
      "NVD_BACKEND"
      "VDPAU_DRIVER"
      "WLR_DRM_DEVICES"
      "WLR_NO_HARDWARE_CURSORS"
      "WLR_RENDERER"
      "__GLX_VENDOR_LIBRARY_NAME"
    ]
  ) combinedSessionEnvironment;

  forbiddenGpuKernelParams = builtins.filter (
    parameter:
    lib.any (needle: lib.hasInfix needle (lib.toLower parameter)) [
      "amdgpu"
      "i915"
      "nouveau"
      "nvidia"
    ]
  ) config.boot.kernelParams;

  excludedDesktopPackages = builtins.filter (
    package:
    builtins.elem (packageName package) [
      "kitty"
      "dunst"
      "eww"
      "fnott"
      "gtklock"
      "ironbar"
      "lxqt-policykit"
      "mate-polkit"
      "polkit-gnome"
      "rofi"
      "swayidle"
      "swaylock"
      "swaynotificationcenter"
      "tofi"
      "walker"
      "wofi"
      "yambar"
    ]
  ) home.home.packages;
in
assert lib.assertMsg (
  !config.services.desktopManager.gnome.enable
) "nixbox Hyprland desktop must disable the GNOME desktop session";
assert lib.assertMsg config.services.displayManager.gdm.enable
  "nixbox Hyprland desktop must retain GDM for the first trial";
assert lib.assertMsg config.programs.hyprland.enable
  "nixbox Hyprland desktop must enable the locked NixOS Hyprland module";
assert lib.assertMsg (
  lib.getVersion config.programs.hyprland.package == "0.55.4"
) "nixbox Hyprland desktop must remain mapped to the reviewed upstream v0.55.4 release";
assert lib.assertMsg config.programs.hyprland.withUWSM
  "nixbox Hyprland desktop must launch Hyprland through UWSM";
assert lib.assertMsg
  (
    builtins.elem "hyprland-uwsm" config.programs.hyprland.package.providedSessions
    && displaySessionPackageNames == [ "hyprland" ]
  )
  "nixbox GDM must expose the locked Hyprland package and its UWSM session without a GNOME desktop session";
assert lib.assertMsg (
  config.programs.hyprland.xwayland.enable && config.programs.xwayland.enable
) "nixbox Hyprland desktop must retain XWayland support";
assert lib.assertMsg (
  config.xdg.portal.enable
  &&
    desktopPortalNames == [
      "xdg-desktop-portal-gtk"
      "xdg-desktop-portal-hyprland"
    ]
) "nixbox desktop portal implementations must be exactly Hyprland and GTK";
assert lib.assertMsg (
  !config.xdg.portal.wlr.enable
) "nixbox Hyprland desktop must not enable the redundant wlr portal";
assert lib.assertMsg config.security.polkit.enable
  "nixbox Hyprland desktop must retain the NixOS polkit service";
assert lib.assertMsg config.programs.dconf.enable
  "nixbox Hyprland desktop must retain dconf required by IBus";
assert lib.assertMsg (
  config.i18n.inputMethod.enable && config.i18n.inputMethod.type == "ibus"
) "nixbox Hyprland desktop must explicitly retain IBus ownership";
assert lib.assertMsg config.services.gnome.gnome-keyring.enable
  "nixbox Hyprland desktop must explicitly retain GNOME Keyring as the secret-service owner";
assert lib.assertMsg config.services.gnome.gcr-ssh-agent.enable
  "nixbox Hyprland desktop must retain the GCR SSH agent implied by the keyring owner";
assert lib.assertMsg config.security.pam.services.login.enableGnomeKeyring
  "nixbox login PAM policy must initialize and unlock the retained GNOME Keyring owner";
assert lib.assertMsg config.hardware.bluetooth.enable
  "nixbox Hyprland migration must preserve the inventoried Bluetooth capability";
assert lib.assertMsg config.services.accounts-daemon.enable
  "nixbox Hyprland migration must retain GDM's AccountsService owner";
assert lib.assertMsg (
  !config.services.udisks2.enable
  && !config.services.upower.enable
  && !config.services.power-profiles-daemon.enable
) "nixbox first Hyprland trial must not inherit unapproved GNOME storage or power daemons";
assert lib.assertMsg (
  builtins.elem pkgs.qt5.qtwayland config.environment.systemPackages
  && builtins.elem pkgs.qt6.qtwayland config.environment.systemPackages
) "nixbox Hyprland desktop must provide both Qt5 and Qt6 native Wayland plugins";
assert lib.assertMsg (
  forbiddenGpuEnvironment == { }
  && forbiddenGpuKernelParams == [ ]
  &&
    lib.sort lib.lessThan config.services.xserver.videoDrivers == [
      "fbdev"
      "modesetting"
    ]
) "nixbox Hyprland trial must not add vendor-specific GPU environment or kernel workarounds";

assert lib.assertMsg home.wayland.windowManager.hyprland.enable
  "nixbox Home Manager must own the reviewed Hyprland user configuration";
assert lib.assertMsg (
  home.wayland.windowManager.hyprland.package == null
  && home.wayland.windowManager.hyprland.portalPackage == null
) "nixbox Home Manager must not duplicate the system-owned Hyprland package or portal";
assert lib.assertMsg (
  !home.wayland.windowManager.hyprland.systemd.enable
) "nixbox Home Manager Hyprland systemd integration must stay disabled under UWSM";
assert lib.assertMsg (
  home.wayland.windowManager.hyprland.plugins == [ ]
) "nixbox Hyprland trial must not introduce Hyprland plugins";
assert lib.assertMsg (
  home.wayland.windowManager.hyprland.configType == "lua"
) "nixbox Home Manager must render the reviewed Hyprland configuration as Lua";
assert lib.assertMsg (
  home.wayland.windowManager.hyprland.settings.terminal._var == "uwsm app -- ghostty"
) "nixbox Hyprland Lua terminal variable must launch Ghostty through UWSM";
assert lib.assertMsg
  (
    lib.hasInfix ''local terminal = "uwsm app -- ghostty"'' home.xdg.configFile."hypr/hyprland.lua".text
    && !lib.hasInfix "hl.$terminal" home.xdg.configFile."hypr/hyprland.lua".text
  )
  "nixbox generated Hyprland Lua must declare the UWSM-wrapped terminal as a local instead of an invalid hl.$terminal call";
assert lib.assertMsg home.programs.ghostty.enable
  "nixbox Hyprland desktop must retain the existing Ghostty capability";
assert lib.assertMsg (
  !home.programs.kitty.enable
) "nixbox Hyprland desktop must not enable Kitty alongside Ghostty";

assert lib.assertMsg home.programs.fuzzel.enable
  "nixbox Hyprland desktop must use Fuzzel as its single mapped launcher owner";
assert lib.assertMsg home.services.mako.enable
  "nixbox Hyprland desktop must use Mako as its single mapped notification owner";
assert lib.assertMsg home.services.hyprpolkitagent.enable
  "nixbox Hyprland desktop must use hyprpolkitagent as its single mapped authentication-agent owner";
assert lib.assertMsg (
  home.systemd.user.services ? hyprpolkitagent
  &&
    home.systemd.user.services.hyprpolkitagent.Service.ExecStart
    == [ "${home.services.hyprpolkitagent.package}/libexec/hyprpolkitagent" ]
) "nixbox hyprpolkitagent owner must use the locked Home Manager unit and package";
assert lib.assertMsg (
  packageCount "fuzzel" home.home.packages == 1 && packageCount "mako" home.home.packages == 1
) "nixbox desktop must expose exactly one package for each mapped launcher and notifier owner";
assert lib.assertMsg (
  home.programs.waybar.enable && home.programs.waybar.systemd.enable
) "nixbox Hyprland desktop must use the Home Manager Waybar systemd owner";
assert lib.assertMsg (
  packageCount "waybar" home.home.packages == 1
) "nixbox Hyprland desktop must expose exactly one Waybar package owner";
assert lib.assertMsg (
  home.systemd.user.services ? waybar
  &&
    home.systemd.user.services.waybar.Service.ExecStart
    == [ "${home.programs.waybar.package}/bin/waybar" ]
) "nixbox Waybar owner must use the locked Home Manager unit and package";
assert lib.assertMsg (
  !home.services.polkit-gnome.enable
) "nixbox desktop must not run a second polkit-gnome authentication agent";
assert lib.assertMsg
  (
    !home.services.dunst.enable
    && !home.services.fnott.enable
    && !home.services.swaync.enable
    && !home.services.walker.enable
    && !home.services.swayidle.enable
    && !home.programs.swaylock.enable
    && !home.programs.rofi.enable
    && !home.programs.wofi.enable
    && !home.programs.tofi.enable
    && !home.programs.anyrun.enable
    && !home.programs.eww.enable
    && !config.programs.hyprlock.enable
    && !config.services.hypridle.enable
    && !config.programs.niri.enable
    && !config.programs.sway.enable
  )
  "nixbox first Hyprland trial must not enable alternative bar, launcher, notifier, locker, idle or compositor owners";
assert lib.assertMsg (
  excludedDesktopPackages == [ ]
) "nixbox first Hyprland trial must not add Kitty or alternative launcher/notifier owners";

assert lib.assertMsg home.programs.hyprlock.enable
  "nixbox Hyprland desktop must use Home Manager Hyprlock as its lock owner";
assert lib.assertMsg (home.programs.hyprlock.settings.input-field != [ ])
  "nixbox Hyprlock must render an input field instead of starting without a usable lock configuration";
assert lib.assertMsg home.services.hypridle.enable
  "nixbox Hyprland desktop must use Home Manager Hypridle as its idle owner";
assert lib.assertMsg (
  config.security.pam.services ? hyprlock
) "nixbox must provide the PAM service required by the Home Manager Hyprlock owner";
assert lib.assertMsg (
  home.services.hypridle.settings.general == {
    after_sleep_cmd = "hyprctl dispatch dpms on";
    before_sleep_cmd = "loginctl lock-session";
    lock_cmd = "pidof hyprlock || hyprlock";
  }
) "nixbox Hypridle must use the reviewed official general lock and sleep commands";
assert lib.assertMsg (home.services.hypridle.settings.listener == [ ])
  "nixbox always-on policy must leave Hypridle listeners empty to avoid automatic lock, display-off, or suspend";

assert lib.assertMsg config.networking.networkmanager.enable
  "nixbox Hyprland migration must retain NetworkManager";
assert lib.assertMsg (
  config.services.avahi.enable && builtins.elem 5353 config.networking.firewall.allowedUDPPorts
) "nixbox Hyprland migration must preserve the existing Avahi and mDNS firewall baseline";
assert lib.assertMsg (
  config.services.pipewire.enable
  && config.services.pipewire.alsa.enable
  && config.services.pipewire.alsa.support32Bit
  && config.services.pipewire.pulse.enable
  && config.services.pipewire.wireplumber.enable
  && !config.services.pulseaudio.enable
) "nixbox Hyprland migration must retain the established PipeWire audio baseline";
assert lib.assertMsg config.services.printing.enable
  "nixbox Hyprland migration must retain printing";
assert lib.assertMsg config.security.rtkit.enable "nixbox Hyprland migration must retain rtkit";
assert lib.assertMsg config.programs.firefox.enable "nixbox Hyprland migration must retain Firefox";
assert lib.assertMsg (
  config.services.openssh.enable
  && config.services.openssh.ports == [ 22 ]
  && !config.services.openssh.settings.PasswordAuthentication
  && !config.services.openssh.settings.KbdInteractiveAuthentication
  && config.services.openssh.settings.PermitRootLogin == "no"
) "nixbox Hyprland migration must preserve native key-only OpenSSH and disabled root login";
assert lib.assertMsg
  (
    config.services.tailscale.enable
    && config.services.tailscale.port == 41641
    && config.services.tailscale.openFirewall
    && config.services.tailscale.useRoutingFeatures == "none"
    &&
      lib.sort (left: right: left < right) config.networking.firewall.allowedTCPPorts == [
        22
        53317
      ]
    &&
      lib.sort (left: right: left < right) config.networking.firewall.allowedUDPPorts == [
        5353
        41641
        53317
      ]
  )
  "nixbox Hyprland migration must preserve Tailscale, LocalSend and the established firewall surface";
assert lib.assertMsg (
  packageCount "codex" home.home.packages == 1
  && packageCount "ax" home.home.packages == 1
  && packageCount "rtk" home.home.packages == 1
  && packageCount "python3" home.home.packages == 1
) "nixbox Hyprland migration must preserve the approved Linux agent toolchain";
assert lib.assertMsg (
  home.programs.direnv.enable
  && home.programs.direnv.nix-direnv.enable
  && home.programs.mise.enable
  && packageCount "uv" home.home.packages == 1
) "nixbox Hyprland migration must preserve the declarative development runtime";
assert lib.assertMsg (
  packageCount "zed-editor" home.home.packages == 1
  && packageCount "nil" home.home.packages == 1
  && packageCount "nixd" home.home.packages == 1
) "nixbox Hyprland migration must preserve Zed and its Nix language servers";
assert lib.assertMsg (
  packageCount "localsend" home.home.packages == 1 && statePathCount "LocalSend" == 1
) "nixbox Hyprland migration must preserve the LocalSend package and mutable-state boundary";
assert lib.assertMsg
  (
    config.sops.age.sshKeyPaths == [ "/etc/ssh/ssh_host_ed25519_key" ]
    && config.sops.gnupg.sshKeyPaths == [ ]
    && config.sops.secrets == { }
  )
  "nixbox Hyprland migration must preserve the approved secret-deployment adapter without adding secrets";
assert lib.assertMsg (
  !config.services.displayManager.gdm.autoSuspend
) "nixbox always-on capability must keep GDM auto-suspend disabled";
assert lib.assertMsg (
  gnomeDconfKeys == [ ]
) "nixbox always-on policy must not retain GNOME-session dconf settings";
pkgs.runCommand "nixbox-hyprland-desktop-policy-check" { } ''
  export XDG_RUNTIME_DIR="$TMPDIR/runtime"
  mkdir -p "$XDG_RUNTIME_DIR"
  ${config.programs.hyprland.package}/bin/Hyprland \
    --verify-config \
    --config ${hyprlandConfig}
  touch "$out"
''
