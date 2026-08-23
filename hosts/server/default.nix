{
  inputs,
  lib,
  username,
  ...
}:

let
  intentLib = import ../../intents/lib.nix;
  git = import ../../software/git { inherit intentLib; };
  gitFoundation = intentLib.realize (git.versionControl intentLib.empty);
  terminalWork = import ../../intents/terminal-work { inherit lib; };
in
{
  # Production reliability takes precedence over mirror proximity. Keep USTC
  # only as a lower-priority fallback for paths absent from the official cache.
  nix.settings.substituters = lib.mkForce [
    "https://cache.nixos.org?priority=40"
    "https://mirrors.ustc.edu.cn/nix-channels/store?priority=50"
  ];

  imports = terminalWork.nixosModules ++ [
    ./disko.nix
    ./networking.nix
    ../../modules/capabilities/portable-shell/nixos.nix
    ../../modules/capabilities/secret-deployment/nixos.nix
    ../../modules/nixos/server-diagnostics.nix
  ];

  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_scsi"
    "sd_mod"
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  users.users = {
    ${username}.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEH/1NOp9oK5riYtfFSK+tkGGCnwTE2z8LGo/+azwjFR sayori-ecs"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG7pbS2HOp0EvAUj35QLEYNpDPmBtS79qJmyU1KLwqpz nixbox-server-deploy-2026-07-30"
    ];

  };

  home-manager = {
    extraSpecialArgs = { inherit inputs; };
    useGlobalPkgs = true;
    useUserPackages = true;

    users.${username} = {
      imports =
        terminalWork.homeModules
        ++ gitFoundation.homeModules
        ++ [
          ../../software/fish/capabilities/interactive-shell/home.nix
          ../../software/atuin/capabilities/shell-history/home.nix
          ../../software/nh/capabilities/nix-operations/home.nix
          ../../software/pay-respects/capabilities/command-correction/home.nix
          ../../software/btop/capabilities/system-monitor/home.nix
          ../../software/fastfetch/capabilities/system-overview/home.nix
          ../../software/yazi/capabilities/terminal-file-manager/home.nix
          ../../software/helix/capabilities/terminal-editor/home.nix
        ];

      home = {
        inherit username;
        homeDirectory = "/home/${username}";
        stateVersion = "26.05";
      };
    };
  };

  system.stateVersion = "26.05";
}
