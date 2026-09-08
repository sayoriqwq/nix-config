{ lib }:

let
  compose = import ../lib.nix { inherit lib; };
  software = {
    fuzzel = import ../../software/fuzzel;
    gdm = import ../../software/gdm;
    gnomeKeyring = import ../../software/gnome-keyring;
    hyprland = import ../../software/hyprland;
    hyprlock = import ../../software/hyprlock;
    hyprpolkitagent = import ../../software/hyprpolkitagent;
    mako = import ../../software/mako;
    networkmanager = import ../../software/networkmanager;
    pipewire = import ../../software/pipewire;
    qtWayland = import ../../software/qt-wayland;
    rtkit = import ../../software/rtkit;
    waybar = import ../../software/waybar;
    xorgServer = import ../../software/xorg-server;
  };
in
compose [
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
