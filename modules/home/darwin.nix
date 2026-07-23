{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [ ./darwin/ghostty ];

  # OMP is a standalone Nix package. It does not depend on the Bun version
  # selected by mise for project development.
  home.packages = [ (pkgs.callPackage ../../packages/oh-my-pi { }) ];

  # The current login shell is Homebrew Fish and does not source nix-darwin's
  # POSIX set-environment script. Add the integrated user profile explicitly.
  home.sessionPath = [ "/etc/profiles/per-user/${config.home.username}/bin" ];

  # Home Manager 26.05 intentionally uses macOS man(1) on Darwin. Fish's
  # cross-platform default would otherwise request an unavailable cache build.
  programs.man.generateCaches = false;

  programs.fish.interactiveShellInit = lib.mkAfter ''
    # Keep un-migrated Darwin tools available after Nix-managed commands.
    fish_add_path --global --path --move --append \
        /opt/homebrew/bin \
        /opt/homebrew/opt/postgresql@16/bin \
        ${config.home.homeDirectory}/Library/pnpm \
        ${config.home.homeDirectory}/.ghcup/bin \
        ${config.home.homeDirectory}/.cabal/bin

    # These applications own their integration files; Home Manager only loads
    # them when present and does not copy their mutable state into the Store.
    test -f "$HOME/.openclaw/completions/openclaw.fish"; and source "$HOME/.openclaw/completions/openclaw.fish"
    test -f "$HOME/.orbstack/shell/init2.fish"; and source "$HOME/.orbstack/shell/init2.fish"

    # Nixpkgs 26.05 removed the unmaintained thefuck package. Keep the existing
    # Homebrew command as a Darwin-only compatibility path for this phase.
    test -x /opt/homebrew/bin/thefuck; and env TF_SHELL=fish /opt/homebrew/bin/thefuck --alias | source
  '';
}
