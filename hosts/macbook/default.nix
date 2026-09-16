{
  inputs,
  lib,
  self,
  ...
}:

let
  chineseInput = import ../../intents/chinese-input.nix { inherit lib; };
  codeDevelopment = import ../../intents/code-development.nix {
    inherit lib;
    withVscode = true;
  };
  containerDevelopment = import ../../intents/container-development.nix;
  developmentRuntime = import ../../intents/development-runtime.nix;
  primaryTerminal = import ../../intents/primary-terminal.nix { inherit lib; };
  githubCollaboration = import ../../intents/github-collaboration.nix;
  shellWork = import ../../intents/shell-work.nix { inherit lib; };
  terminalCompatibility = import ../../intents/terminal-compatibility.nix;
in
{
  imports =
    shellWork.darwinModules
    ++ primaryTerminal.darwinModules
    ++ terminalCompatibility.darwinModules
    ++ codeDevelopment.darwinModules
    ++ containerDevelopment.darwinModules
    ++ chineseInput.darwinModules
    ++ [
      {
        options.system.defaults.controlcenter.Battery = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum [ 2 ]);
          default = null;
          description = ''
            Show the native battery item in the menu bar. The value 2 is the
            macOS 27 ByHost Control Center representation verified on macbook.
          '';
        };

        config.system.defaults = {
          NSGlobalDomain = {
            ApplePressAndHoldEnabled = false;
            AppleShowAllExtensions = true;
            AppleShowScrollBars = "Always";
            InitialKeyRepeat = 15;
            KeyRepeat = 2;
            NSAutomaticCapitalizationEnabled = false;
            NSAutomaticDashSubstitutionEnabled = false;
            NSAutomaticPeriodSubstitutionEnabled = false;
            NSAutomaticQuoteSubstitutionEnabled = false;
            "com.apple.keyboard.fnState" = true;
            "com.apple.swipescrolldirection" = true;
            "com.apple.trackpad.forceClick" = true;
            "com.apple.trackpad.scaling" = 2.0;
          };

          dock = {
            autohide = true;
            minimize-to-application = true;
            mru-spaces = false;
            show-recents = false;
            tilesize = 64;

            showAppExposeGestureEnabled = false;
            showDesktopGestureEnabled = true;
            showMissionControlGestureEnabled = true;

            wvous-tl-corner = 1;
            wvous-tr-corner = 1;
            wvous-bl-corner = 1;
            wvous-br-corner = 14;
          };

          finder = {
            FXPreferredViewStyle = "clmv";
            ShowPathbar = true;
            ShowStatusBar = true;
          };

          trackpad = {
            ActuateDetents = true;
            Clicking = true;
            DragLock = false;
            Dragging = false;
            FirstClickThreshold = 1;
            ForceSuppressed = false;
            SecondClickThreshold = 1;
            TrackpadCornerSecondaryClick = 0;
            TrackpadFourFingerHorizSwipeGesture = 2;
            TrackpadFourFingerPinchGesture = 2;
            TrackpadFourFingerVertSwipeGesture = 2;
            TrackpadMomentumScroll = true;
            TrackpadPinch = true;
            TrackpadRightClick = true;
            TrackpadRotate = true;
            TrackpadThreeFingerDrag = true;
            TrackpadThreeFingerHorizSwipeGesture = 0;
            TrackpadThreeFingerTapGesture = 0;
            TrackpadThreeFingerVertSwipeGesture = 0;
            TrackpadTwoFingerDoubleTapGesture = true;
            TrackpadTwoFingerFromRightEdgeSwipeGesture = 3;
          };

          WindowManager = {
            EnableTilingByEdgeDrag = false;
            EnableTilingOptionAccelerator = false;
            EnableTopTilingByEdgeDrag = false;
          };

          menuExtraClock = {
            Show24Hour = true;
            ShowDate = 1;
            ShowDayOfWeek = true;
            ShowSeconds = false;
          };

          controlcenter = {
            Battery = 2;
            BatteryShowPercentage = true;
          };

          CustomUserPreferences."com.apple.dock" = {
            wvous-tl-modifier = 0;
            wvous-tr-modifier = 0;
            wvous-bl-modifier = 0;
            wvous-br-modifier = 0;
          };
        };
      }
      ../../software/lix/darwin.nix
      ../../software/maple-mono/darwin.nix
      ../../software/homebrew/darwin.nix
      ../../software/amphetamine/darwin.nix
      ../../software/baidu-netdisk/darwin.nix
      ../../software/balena-etcher/darwin.nix
      ../../software/chatgpt/darwin.nix
      ../../software/clash-verge-rev/darwin.nix
      ../../software/easyfind/darwin.nix
      ../../software/feishu/darwin.nix
      ../../software/figma/darwin.nix
      ../../software/fuse-t/darwin.nix
      ../../software/garageband/darwin.nix
      ../../software/google-chrome/darwin.nix
      ../../software/hazeover/darwin.nix
      ../../software/izip/darwin.nix
      ../../software/keynote/darwin.nix
      ../../software/keyscreen/darwin.nix
      ../../software/linear/darwin.nix
      ../../software/mega/darwin.nix
      ../../software/netease-cloud-music/darwin.nix
      ../../software/numbers/darwin.nix
      ../../software/obs-studio/darwin.nix
      ../../software/one-thing/darwin.nix
      ../../software/pages/darwin.nix
      ../../software/paseo/darwin.nix
      ../../software/pearcleaner/darwin.nix
      ../../software/qq/darwin.nix
      ../../software/raycast/darwin.nix
      ../../software/scratch/darwin.nix
      ../../software/telegram/darwin.nix
      ../../software/tencent-meeting/darwin.nix
      ../../software/termius/darwin.nix
      ../../software/topnotch/darwin.nix
      ../../software/transmission/darwin.nix
      ../../software/vorssaint/darwin.nix
      ../../software/wechat/darwin.nix
      ../../software/windows-app/darwin.nix
      ../../software/tailscale/darwin.nix
    ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "discord"
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
        shellWork.homeModules
        ++ primaryTerminal.homeModules
        ++ terminalCompatibility.homeModules
        ++ codeDevelopment.homeModules
        ++ developmentRuntime.homeModules
        ++ containerDevelopment.homeModules
        ++ githubCollaboration.homeModules
        ++ chineseInput.homeModules
        ++ [
          ../../software/obsidian/home-manager.nix
          ../../software/discord/home-manager.nix
          ../../software/iina/home-manager.nix
          ../../software/localsend/home-manager.nix
          ../../software/monitorcontrol/home-manager.nix
          ../../software/mos/home-manager.nix
          ../../software/upscayl/home-manager.nix
          ../../software/xbar/home-manager.nix
          ../../software/rclone/home-manager.nix
          ../../software/tailscale/darwin-home-manager.nix
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
