{
  pkgs,
  username,
  ...
}:

{
  imports = [ ../../nixos/graphical-workstation.nix ];

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  services = {
    xserver = {
      enable = true;
      xkb = {
        layout = "us";
        variant = "";
      };
    };

    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = false;

    # GNOME previously supplied this implicitly. Keep the existing secret
    # service and login-PAM integration without retaining the GNOME desktop.
    gnome.gnome-keyring.enable = true;
  };

  # Phase 5 inventory records Bluetooth as an existing nixbox capability.
  # Keep the controller service without adding device-specific settings.
  hardware.bluetooth.enable = true;

  # The Home Manager Hyprlock package needs a system PAM policy to unlock.
  security.pam.services.hyprlock = { };

  # Hyprland's official must-have guidance requires both Qt generations to
  # have their native Wayland platform plugin available.
  environment.systemPackages = [
    pkgs.qt5.qtwayland
    pkgs.qt6.qtwayland
  ];

  home-manager.users.${username}.imports = [ ./home.nix ];
}
