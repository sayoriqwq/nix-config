{
  config,
  lib,
  pkgs,
  ...
}:

let
  baseline = ../../desktop/editors/vscode/settings.jsonc;
  target = "${config.home.homeDirectory}/Library/Application Support/Code/User/settings.json";

  seedSettings = pkgs.writeShellApplication {
    name = "seed-vscode-settings";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      if [[ $# -ne 2 ]]; then
        echo "usage: seed-vscode-settings TARGET BASELINE" >&2
        exit 2
      fi

      target=$1
      baseline=$2

      if [[ -e "$target" || -L "$target" ]]; then
        exit 0
      fi

      mkdir -p "$(dirname "$target")"
      temporary="$(mktemp "$target.home-manager.XXXXXX")"
      trap 'rm -f "$temporary"' EXIT

      install -m 0644 "$baseline" "$temporary"
      mv --no-clobber "$temporary" "$target"
    '';
  };
in
{
  # VS Code and its extensions keep this file writable. Nix provides only a
  # first-run baseline and never overwrites an existing file or symlink.
  home.activation.seedVscodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${lib.getExe seedSettings} ${lib.escapeShellArg target} ${lib.escapeShellArg (toString baseline)}
  '';
}
