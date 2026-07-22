{
  homebrew = {
    enable = true;

    # GUI application installation belongs to nix-darwin. Home Manager only
    # owns terminal user configuration and does not install duplicate apps.
    casks = [
      "ghostty"
      "wezterm"
    ];

    # Phase 4 adopts applications one at a time. Never remove undeclared
    # Homebrew software during activation.
    onActivation.cleanup = "none";
  };
}
