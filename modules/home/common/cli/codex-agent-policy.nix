{
  home.file.".codex/AGENTS.md" = {
    source = ../../../../dotfiles/codex/AGENTS.md;

    # The tracked policy is authoritative; do not allow a mutable installed
    # copy to diverge from the reviewed Nix generation.
    force = true;
  };
}
