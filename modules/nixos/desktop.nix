{
  networking.networkmanager.enable = true;
  users.users.sayori.extraGroups = [ "networkmanager" ];

  services = {
    xserver = {
      enable = true;
      xkb = {
        layout = "us";
        variant = "";
      };
    };

    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;

    printing.enable = true;
    pulseaudio.enable = false;

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };

  security.rtkit.enable = true;
  programs.firefox.enable = true;
}
