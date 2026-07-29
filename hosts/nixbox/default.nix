{
  inputs,
  username,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/capabilities/portable-shell/nixos.nix
    ../../modules/capabilities/google-chrome/nixos.nix
    ../../modules/capabilities/clash-verge-rev/nixos.nix
    ../../modules/capabilities/termius/nixos.nix
    ../../modules/capabilities/localsend/nixos.nix
  ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking.hostName = "nixos";

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
      imports = [
        ../../modules/home/capabilities/terminal-toolkit.nix
        ../../modules/home/capabilities/terminal-history.nix
        ../../modules/home/capabilities/workstation-history-sync.nix
        ../../modules/home/capabilities/git-foundation.nix
        ../../modules/home/capabilities/github-collaboration.nix
        ../../modules/home/capabilities/nix-operations.nix
        ../../modules/home/capabilities/interactive-shell-assistance.nix
        ../../modules/home/capabilities/host-observability.nix
        ../../modules/home/capabilities/development-runtime.nix
        ../../modules/home/capabilities/terminal-file-workflow.nix
        ../../modules/home/capabilities/helix-editor.nix
        ../../modules/home/capabilities/zed-editor.nix
        ../../modules/home/capabilities/ghostty-terminal.nix
        ../../modules/home/capabilities/obsidian/linux.nix
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
