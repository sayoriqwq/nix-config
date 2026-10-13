{
  inputs,
  lib,
  username,
  ...
}:

let
  chineseInput = import ../../intents/chinese-input.nix { inherit lib; };
  codeDevelopment = import ../../intents/code-development.nix { inherit lib; };
  developmentRuntime = import ../../intents/development-runtime.nix;
  primaryTerminal = import ../../intents/primary-terminal.nix { inherit lib; };
  githubCollaboration = import ../../intents/github-collaboration.nix;
  hyprlandWorkstation = import ../../intents/hyprland-workstation.nix { inherit lib; };
  shellWork = import ../../intents/shell-work.nix { inherit lib; };
in
{
  # Nix 按显式优先级选择缓存；此工作站优先使用就近镜像，再回退官方缓存。
  nix.settings.substituters = lib.mkForce [
    "https://mirrors.ustc.edu.cn/nix-channels/store?priority=30"
    "https://cache.nixos.org?priority=40"
  ];

  imports =
    shellWork.nixosModules
    ++ primaryTerminal.nixosModules
    ++ hyprlandWorkstation.nixosModules
    ++ chineseInput.nixosModules
    ++ [
      ./hardware-configuration.nix
      ../../shared/administrator-nixos.nix
      ../../software/avahi/nixos.nix
      ../../software/bluez/nixos.nix
      ../../software/curl/nixos.nix
      ../../software/clash-verge-rev/nixos.nix
      ../../software/nix/nixos.nix
      ../../software/nixpkgs/nixos.nix
      ../../software/openssh/key-only-remote-access-nixos.nix
      ../../software/pciutils/nixos.nix
      ../../software/localsend/nixos.nix
      ../../software/tailscale/nixos.nix
      ../../software/usbutils/nixos.nix
      ../../software/vim/nixos.nix
      ../../software/wget/nixos.nix
    ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking.hostName = "nixos";

  users.users.${username}.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIILj3vb/coYALTSiSSrCE5+wFeTwPBGUKjbrY1Ap7XOM sayori@nixbox-codex"
  ];

  time.timeZone = "Asia/Shanghai";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "zh_CN.UTF-8";
      LC_IDENTIFICATION = "zh_CN.UTF-8";
      LC_MEASUREMENT = "zh_CN.UTF-8";
      LC_MONETARY = "zh_CN.UTF-8";
      LC_NAME = "zh_CN.UTF-8";
      LC_NUMERIC = "zh_CN.UTF-8";
      LC_PAPER = "zh_CN.UTF-8";
      LC_TELEPHONE = "zh_CN.UTF-8";
      LC_TIME = "zh_CN.UTF-8";
    };
  };

  home-manager = {
    extraSpecialArgs = { inherit inputs; };
    useGlobalPkgs = true;
    useUserPackages = true;

    users.${username} = {
      imports =
        shellWork.homeModules
        ++ primaryTerminal.homeModules
        ++ codeDevelopment.homeModules
        ++ developmentRuntime.homeModules
        ++ githubCollaboration.homeModules
        ++ hyprlandWorkstation.homeModules
        ++ [
          ../../software/obsidian/home-manager.nix
          ../../software/google-chrome/linux-home-manager.nix
          ../../software/termius/linux-home-manager.nix
        ];

      home = {
        inherit username;
        homeDirectory = "/home/${username}";

        # 首次启用后的兼容版本保持不变。
        stateVersion = "26.05";
      };
    };
  };

  system.stateVersion = "26.05";
}
