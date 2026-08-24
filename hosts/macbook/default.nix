{
  inputs,
  lib,
  self,
  ...
}:

let
  aiCoding = import ../../intents/ai-coding { inherit lib; };
  chineseInput = import ../../intents/chinese-input { inherit lib; };
  codeDevelopment = import ../../intents/code-development { inherit lib; };
  intentLib = import ../../intents/lib.nix;
  pinshift = import ../../software/pinshift { inherit intentLib; };
  pinshiftDevelopment = intentLib.realize (pinshift.developmentCli intentLib.empty);
  terminalWork = import ../../intents/terminal-work { inherit lib; };
  terminalCompatibility = import ../../intents/terminal-compatibility { inherit lib; };
  terminalHomeModules = terminalWork.homeModules ++ terminalCompatibility.homeModules;
  workstationHomeModules =
    codeDevelopment.homeModules
    ++ aiCoding.multiClientCodingEnvironment.homeModules
    ++ pinshiftDevelopment.homeModules;
in
{
  imports =
    terminalWork.darwinModules
    ++ codeDevelopment.darwinModules
    ++ chineseInput.darwinModules
    ++ [
      ../../modules/darwin/workstation-defaults.nix
      ../../software/fish/capabilities/interactive-shell/darwin.nix
      ../../software/lix/capabilities/nix-daemon/darwin.nix
      ../../software/maple-mono/capabilities/workstation-font/darwin.nix
      ../../software/homebrew/capabilities/non-destructive-application-management/darwin.nix
      ../../software/amphetamine/capabilities/sleep-control/darwin.nix
      ../../software/baidu-netdisk/capabilities/cloud-storage-client/darwin.nix
      ../../software/balena-etcher/capabilities/disk-image-writer/darwin.nix
      ../../software/chatgpt/capabilities/desktop-ai-client/darwin.nix
      ../../software/clash-verge-rev/capabilities/proxy-client/darwin.nix
      ../../software/easyfind/capabilities/file-search/darwin.nix
      ../../software/feishu/capabilities/team-collaboration/darwin.nix
      ../../software/figma/capabilities/interface-design/darwin.nix
      ../../software/fuse-t/capabilities/filesystem-bridge/darwin.nix
      ../../software/garageband/capabilities/music-creation/darwin.nix
      ../../software/google-chrome/capabilities/web-browser/darwin.nix
      ../../software/hazeover/capabilities/focus-overlay/darwin.nix
      ../../software/izip/capabilities/archive-manager/darwin.nix
      ../../software/keynote/capabilities/presentation-editing/darwin.nix
      ../../software/keyscreen/capabilities/keystroke-visualization/darwin.nix
      ../../software/linear/capabilities/issue-tracking/darwin.nix
      ../../software/mega/capabilities/cloud-storage-client/darwin.nix
      ../../software/netease-cloud-music/capabilities/music-player/darwin.nix
      ../../software/numbers/capabilities/spreadsheet-editing/darwin.nix
      ../../software/obs-studio/capabilities/screen-recording/darwin.nix
      ../../software/one-thing/capabilities/menu-bar-reminder/darwin.nix
      ../../software/orbstack/capabilities/container-runtime/darwin.nix
      ../../software/pages/capabilities/document-editing/darwin.nix
      ../../software/paseo/capabilities/application-presence/darwin.nix
      ../../software/pearcleaner/capabilities/app-maintenance/darwin.nix
      ../../software/qq/capabilities/messaging/darwin.nix
      ../../software/raycast/capabilities/application-launcher/darwin.nix
      ../../software/scratch/capabilities/markdown-editor/darwin.nix
      ../../software/telegram/capabilities/messaging/darwin.nix
      ../../software/tencent-meeting/capabilities/video-conferencing/darwin.nix
      ../../software/termius/capabilities/remote-access-client/darwin.nix
      ../../software/topnotch/capabilities/display-customization/darwin.nix
      ../../software/transmission/capabilities/bittorrent-client/darwin.nix
      ../../software/vorssaint/capabilities/application-presence/darwin.nix
      ../../software/wechat/capabilities/messaging/darwin.nix
      ../../software/windows-app/capabilities/windows-remote-access/darwin.nix
      ../../software/localsend/capabilities/local-file-sharing/darwin.nix
      ../../software/tailscale/capabilities/stable-workstation-access/darwin.nix
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
      imports =
        terminalHomeModules
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
          ../../modules/home/capabilities/macos-development-runtime-extras.nix
          ../../software/yazi/capabilities/terminal-file-manager/home.nix
          ../../software/helix/capabilities/terminal-editor/home.nix
          ../../software/vscode/capabilities/editor-compatibility/home.nix
          ../../software/ghostty/capabilities/terminal-emulator/home.nix
          ../../software/obsidian/capabilities/knowledge-base/darwin-home.nix
          ../../software/discord/capabilities/messaging/home.nix
          ../../software/iina/capabilities/media-player/home.nix
          ../../software/man/capabilities/manual-pages/home.nix
          ../../software/monitorcontrol/capabilities/display-control/home.nix
          ../../software/mos/capabilities/mouse-utility/home.nix
          ../../software/upscayl/capabilities/image-upscaling/home.nix
          ../../software/xbar/capabilities/menu-bar-plugins/home.nix
          ../../software/rclone/capabilities/cloud-storage/home.nix
          ../../software/tailscale/capabilities/stable-workstation-access/darwin-home.nix
          ../../modules/home/capabilities/shortcut-reference.nix
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
