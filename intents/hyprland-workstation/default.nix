{ lib }:

let
  intentLib = import ../lib.nix;
  software = {
    fuzzel = import ../../software/fuzzel { inherit intentLib; };
    gdm = import ../../software/gdm { inherit intentLib; };
    gnomeKeyring = import ../../software/gnome-keyring { inherit intentLib; };
    hyprland = import ../../software/hyprland { inherit intentLib; };
    hyprlock = import ../../software/hyprlock { inherit intentLib; };
    hyprpolkitagent = import ../../software/hyprpolkitagent { inherit intentLib; };
    mako = import ../../software/mako { inherit intentLib; };
    networkmanager = import ../../software/networkmanager { inherit intentLib; };
    pipewire = import ../../software/pipewire { inherit intentLib; };
    qtWayland = import ../../software/qt-wayland { inherit intentLib; };
    rtkit = import ../../software/rtkit { inherit intentLib; };
    waybar = import ../../software/waybar { inherit intentLib; };
    xorgServer = import ../../software/xorg-server { inherit intentLib; };
  };
in
intentLib.realize (
  lib.pipe intentLib.empty [
    software.hyprland.graphicalSession
    software.gdm.displayManager
    software.xorgServer.compatibilityServer
    software.qtWayland.platformPlugins
    software.gnomeKeyring.secretService
    software.hyprlock.sessionLock
    software.fuzzel.applicationLauncher
    software.waybar.desktopStatus
    software.hyprpolkitagent.authenticationAgent
    software.mako.notificationDaemon
    software.networkmanager.networkConnectivity
    software.pipewire.desktopAudio
    software.rtkit.realtimeScheduling
  ]
)
