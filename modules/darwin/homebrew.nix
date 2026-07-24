{
  homebrew = {
    enable = true;

    casks = [
      # VS Code is distributed as the upstream signed macOS application.
      # Home Manager owns only its stable user settings and must not install a
      # second application package.
      "visual-studio-code"
    ];

    # Ghostty and WezTerm are now owned by Home Manager/Nix. Keep global
    # cleanup disabled: their existing casks are removed later by an explicit,
    # targeted and separately approved handoff.
    onActivation.cleanup = "none";
  };
}
