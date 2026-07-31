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
      "claude-code"
      "easyfind"
      "erictli/tap/scratch"
      "figma"
      "fuse-t"
      "izip"
      "lark"
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
      "topnotch"
      "transmission"
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
      upgrade = false;
      cleanup = "none";
    };
  };
}
