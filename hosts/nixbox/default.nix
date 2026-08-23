{
  inputs,
  lib,
  username,
  ...
}:

let
  aiCoding = import ../../intents/ai-coding { inherit lib; };
  alwaysOnWorkstation = import ../../intents/always-on-workstation { inherit lib; };
  chineseInput = import ../../intents/chinese-input { inherit lib; };
  codeDevelopment = import ../../intents/code-development { inherit lib; };
  hyprlandWorkstation = import ../../intents/hyprland-workstation { inherit lib; };
  terminalWork = import ../../intents/terminal-work { inherit lib; };
  workstationHomeModules = codeDevelopment.homeModules ++ aiCoding.coreCodingEnvironment.homeModules;
in
{
  # Nix chooses substituters by their explicit priority, not list position.
  # Prefer the nearby USTC mirror on this interactive workstation, then fall
  # back to the official cache. Capability-specific caches remain additive.
  nix.settings.substituters = lib.mkForce [
    "https://mirrors.ustc.edu.cn/nix-channels/store?priority=30"
    "https://cache.nixos.org?priority=40"
  ];

  imports =
    terminalWork.nixosModules
    ++ hyprlandWorkstation.nixosModules
    ++ alwaysOnWorkstation.nixosModules
    ++ chineseInput.nixosModules
    ++ [
      ./hardware-configuration.nix
      ../../modules/nixos/administrator-user.nix
      ../../software/avahi/capabilities/mdns/nixos.nix
      ../../software/bluez/capabilities/bluetooth/nixos.nix
      ../../software/curl/capabilities/network-transfer/nixos.nix
      ../../software/fish/capabilities/interactive-shell/nixos.nix
      ../../software/google-chrome/capabilities/web-browser/nixos.nix
      ../../software/clash-verge-rev/capabilities/proxy-client/nixos.nix
      ../../software/nix/capabilities/flake-interface/nixos.nix
      ../../software/nixpkgs/capabilities/unfree-package-policy/nixos.nix
      ../../software/openssh/capabilities/key-only-remote-access/nixos.nix
      ../../software/pciutils/capabilities/hardware-inspection/nixos.nix
      ../../software/termius/capabilities/remote-access-client/nixos.nix
      ../../software/localsend/capabilities/local-file-sharing/nixos.nix
      ../../software/tailscale/capabilities/stable-workstation-access/nixos.nix
      ../../software/usbutils/capabilities/hardware-inspection/nixos.nix
      ../../software/vim/capabilities/system-editor/nixos.nix
      ../../software/wget/capabilities/network-download/nixos.nix
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
        terminalWork.homeModules
        ++ hyprlandWorkstation.homeModules
        ++ alwaysOnWorkstation.homeModules
        ++ workstationHomeModules
        ++ [
          ../../software/fish/capabilities/interactive-shell/home.nix
          ../../software/atuin/capabilities/shell-history/home.nix
          ../../modules/home/capabilities/github-collaboration.nix
          ../../software/nh/capabilities/nix-operations/home.nix
          ../../software/pay-respects/capabilities/command-correction/home.nix
          ../../software/btop/capabilities/system-monitor/home.nix
          ../../software/fastfetch/capabilities/system-overview/home.nix
          ../../modules/home/capabilities/development-runtime.nix
          ../../software/yazi/capabilities/terminal-file-manager/home.nix
          ../../software/helix/capabilities/terminal-editor/home.nix
          ../../software/ghostty/capabilities/terminal-emulator/home.nix
          ../../software/obsidian/capabilities/knowledge-base/linux-home.nix
          ../../modules/home/capabilities/shortcut-reference.nix
        ];

      home = {
        inherit username;
        homeDirectory = "/home/${username}";

        # This is nixbox's first Home Manager adoption. Keep the initial
        # value unchanged after activation.
        stateVersion = "26.05";
      };
    };
  };

  system.stateVersion = "26.05";
}
