{
  networking.networkmanager.enable = true;
  users.users.sayori.extraGroups = [ "networkmanager" ];

  services = {
    # GNOME previously supplied the existing mDNS owner implicitly. Preserve
    # the established UDP 5353 firewall baseline while changing sessions.
    avahi.enable = true;

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
