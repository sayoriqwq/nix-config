{
  homebrew = {
    enable = true;

    taps = [
      {
        name = "erictli/tap";
        trusted = true;
      }
    ];

    casks = [
      "baidunetdisk"
      "balenaetcher"
      "chatgpt"
      "clash-verge-rev"
      "claude-code"
      "easyfind"
      "erictli/tap/scratch"
      "figma"
      "fuse-t"
      "google-chrome"
      "izip"
      "linear"
      "megasync"
      "neteasemusic"
      "homebrew/cask/obs"
      "orbstack"
      "paseo"
      "pearcleaner"
      "qq"
      "raycast"
      "steam"
      "telegram"
      "tencent-meeting"
      "termius"
      "topnotch"
      "transmission"
      "typeless"
      "vorssaint"
      "wechat"
    ];

    masApps = {
      Amphetamine = 937984704;
      GarageBand = 682658836;
      HazeOver = 430798174;
      KeyScreen = 6753302381;
      Keynote = 409183694;
      Numbers = 409203825;
      "One Thing" = 1604176982;
      Pages = 409201541;
      "Windows App" = 1295203466;
    };

    onActivation = {
      autoUpdate = false;

      # Existing apps and App Store receipts must not be upgraded during an
      # ordinary system activation.
      upgrade = false;

      # Old Nix-owned casks and explicitly retired software are removed only
      # by a targeted, separately approved cleanup batch.
      cleanup = "none";
    };
  };
}
