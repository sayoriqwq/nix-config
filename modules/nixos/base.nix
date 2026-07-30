{
  pkgs,
  username,
  ...
}:

{
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      substituters = [
        "https://mirrors.ustc.edu.cn/nix-channels/store"
        "https://cache.nixos.org"
      ];
    };
  };

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    curl
    pciutils
    usbutils
  ];

  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = [ "wheel" ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };
}
