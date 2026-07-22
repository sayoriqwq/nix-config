{
  imports = [
    ./settings.nix
    ./themes/sayoriqwq-obsidian.nix
  ];

  programs.ghostty = {
    enable = true;

    # The macOS application is installed by nix-darwin's Homebrew cask.
    package = null;

    # Ghostty already injects its shell integration into the configured Fish
    # login shell. Avoid adding a second integration through Home Manager.
    enableFishIntegration = false;
  };
}
