{ pkgs, ... }:

let
  obsidian =
    if pkgs.stdenv.hostPlatform.isDarwin then
      pkgs.obsidian.overrideAttrs (_old: {
        # The unstable Darwin DMG currently nests Obsidian.app under a
        # versioned directory, while the package's sourceRoot expects it at
        # the archive root.
        sourceRoot = null;
        setSourceRoot = ''
          sourceRoot="$(find . -type d -name 'Obsidian.app' -print -quit)"
          if [ -z "$sourceRoot" ]; then
            echo "Obsidian.app was not found in the unpacked DMG" >&2
            exit 1
          fi
        '';
      })
    else
      pkgs.obsidian;
in

{
  imports = [
    ../../common/state-paths.nix
  ];

  home.packages = [ obsidian ];
}
