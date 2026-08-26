{ homeManager, pkgs }:

let
  home = homeManager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      ../../software/zoxide/capabilities/directory-jumper/zsh.nix
      {
        home = {
          username = "zoxide-zsh-check";
          homeDirectory = "/tmp/zoxide-zsh-check";
          stateVersion = "26.05";
        };
      }
    ];
  };
  zshInit = pkgs.writeText "zoxide-zsh-init.zsh" home.config.programs.zsh.initContent;
  zoxideMock = pkgs.writeShellScriptBin "zoxide" ''
    if [[ " $* " == *" --list "* && "''${!#}" == "space-match" ]]; then
      printf '%s\n' "$ZOXIDE_SPACE_TARGET"
    fi
  '';
in
pkgs.runCommand "zoxide-zsh-behavior"
  {
    nativeBuildInputs = [
      pkgs.zsh
      zoxideMock
    ];
  }
  ''
    zsh -df <<'EOF'
    source ${zshInit}

    typeset -ga fallback_args=()
    function __zoxide_z() {
      fallback_args=("$@")
    }

    __sayori_cd no-match
    (( ''${#fallback_args[@]} == 1 )) || exit 1
    [[ "''${fallback_args[1]}" == "no-match" ]] || exit 1

    space_target="$TMPDIR/directory with spaces"
    mkdir -p "$space_target"
    export ZOXIDE_SPACE_TARGET="$space_target"
    __sayori_cd space-match
    [[ "$PWD" == "$space_target" ]] || exit 1
    EOF

    touch "$out"
  ''
