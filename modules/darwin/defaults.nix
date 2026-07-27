{ lib, ... }:

{
  # nix-darwin already writes this option set to the primary user's ByHost
  # Control Center plist. The pinned release lacks only the battery visibility
  # key used by macOS 27, so extend the existing interface instead of adding a
  # second activation path.
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
