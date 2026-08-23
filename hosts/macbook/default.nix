{
  inputs,
  lib,
  self,
  ...
}:

{
  imports = [
    ../../modules/darwin/defaults.nix
    ../../modules/darwin/fonts.nix
    ../../modules/darwin/shell.nix
    ../../modules/capabilities/raycast/darwin.nix
    ../../modules/capabilities/macos-legacy-applications/darwin.nix
    ../../modules/capabilities/google-chrome/darwin.nix
    ../../modules/capabilities/clash-verge-rev/darwin.nix
    ../../modules/capabilities/termius/darwin.nix
    ../../modules/capabilities/zed-editor/darwin.nix
    ../../modules/capabilities/localsend/darwin.nix
    ../../modules/capabilities/stable-workstation-access/darwin.nix
    ../../modules/capabilities/secret-deployment/darwin.nix
    ../../modules/capabilities/chinese-input/darwin.nix
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "discord"
      "claude-code"
      "antigravity-cli"
      "mos"
      "obsidian"
      "vscode"
    ];

  environment.etc."shells".knownSha256Hashes = [
    # macOS defaults plus this host's pre-migration Homebrew Fish registration.
    "1655f96aad74ad3fd074d08a2c38fe4253ba120ed8937996f4deb89abccc2e41"
  ];

  system = {
    primaryUser = "sayori";
    configurationRevision = self.rev or self.dirtyRev or null;

    # This is the current value recommended for a new installation by the
    # pinned nix-darwin module. Keep it unchanged after the first activation.
    stateVersion = 7;
  };

  users.users.sayori = {
    uid = 501;
    home = "/Users/sayori";
  };

  home-manager = {
    extraSpecialArgs = { inherit inputs; };
    useGlobalPkgs = true;
    useUserPackages = true;

    users.sayori = {
      imports = [
        ../../modules/home/capabilities/portable-shell.nix
        ../../modules/home/capabilities/terminal-toolkit.nix
        ../../modules/home/capabilities/herdr.nix
        ../../modules/home/capabilities/terminal-history.nix
        ../../modules/home/capabilities/workstation-history-sync.nix
        ../../modules/home/capabilities/macos-atuin-desktop.nix
        ../../modules/home/capabilities/git-foundation.nix
        ../../modules/home/capabilities/github-collaboration.nix
        ../../modules/home/capabilities/nix-operations.nix
        ../../modules/home/capabilities/interactive-shell-assistance.nix
        ../../modules/home/capabilities/host-observability.nix
        ../../modules/home/capabilities/development-runtime.nix
        ../../modules/home/capabilities/macos-development-runtime-extras.nix
        ../../modules/home/capabilities/terminal-file-workflow.nix
        ../../modules/home/capabilities/helix-editor.nix
        ../../modules/home/capabilities/macos-vscode-compatibility.nix
        ../../modules/home/capabilities/ghostty-terminal.nix
        ../../modules/home/capabilities/macos-terminal-compatibility.nix
        ../../modules/home/capabilities/obsidian/darwin.nix
        ../../modules/home/capabilities/macos-user-applications.nix
        ../../modules/home/capabilities/macos-integrations.nix
        ../../modules/home/capabilities/ai-assisted-operations.nix
        ../../modules/home/capabilities/cloud-storage.nix
        ../../modules/home/capabilities/shortcut-reference.nix
        ../../modules/home/capabilities/secret-administration.nix
      ];

      home = {
        username = "sayori";
        homeDirectory = "/Users/sayori";

        # This is the first Home Manager adoption. The pinned 26.05 manual
        # requires the initial value to remain unchanged after activation.
        stateVersion = "26.05";
      };
    };
  };

  # Preserve the pre-existing macOS sudo_local behavior during adoption.
  security.pam.services.sudo_local.touchIdAuth = true;
}
