{
  homebrew = {
    enable = true;

    # GUI application installation belongs to nix-darwin. Home Manager only
    # owns Ghostty's user configuration and does not install another package.
    casks = [ "ghostty" ];

    # Phase 4 adopts applications one at a time. Never remove undeclared
    # Homebrew software during activation.
    onActivation.cleanup = "none";
  };
}
