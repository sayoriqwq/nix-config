{
  imports = [
    ./cli
    ./editors
    ./integrations
  ];

  # Home Manager 26.05 intentionally uses macOS man(1) on Darwin. Fish's
  # cross-platform default would otherwise request an unavailable cache build.
  programs.man.generateCaches = false;
}
