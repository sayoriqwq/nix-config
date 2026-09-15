{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkIf mkOption types;
  files = config.sayori.editors.seedFiles;

  seedEditorFile = pkgs.writeShellApplication {
    name = "seed-editor-file";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      if [[ $# -ne 2 ]]; then
        echo "usage: seed-editor-file TARGET BASELINE" >&2
        exit 2
      fi

      target=$1
      baseline=$2

      # Regular files, directories, symlinks and dangling symlinks are all
      # existing user state. Never replace any of them during activation.
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
  options.sayori.editors.seedFiles = mkOption {
    type = types.listOf (
      types.submodule {
        options = {
          target = mkOption { type = types.str; };
          baseline = mkOption { type = types.path; };
        };
      }
    );
    default = [ ];
    description = "Writable editor files initialized only when no target exists";
  };

  config = mkIf (files != [ ]) {
    home.activation.seedEditorFiles = lib.hm.dag.entryAfter [ "writeBoundary" ] (
      lib.concatMapStringsSep "\n" (
        file:
        "run ${lib.getExe seedEditorFile} ${lib.escapeShellArg file.target} ${lib.escapeShellArg (toString file.baseline)}"
      ) files
    );
  };
}
