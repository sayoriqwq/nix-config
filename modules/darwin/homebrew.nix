{
  homebrew = {
    enable = true;

    # Ghostty and WezTerm are now owned by Home Manager/Nix. Keep global
    # cleanup disabled: their existing casks are removed later by an explicit,
    # targeted and separately approved handoff.
    onActivation.cleanup = "none";
  };
}
