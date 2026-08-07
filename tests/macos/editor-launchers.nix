{
  lib,
  macbookConfiguration,
  nixboxConfiguration,
  pkgs,
  serverConfiguration,
}:

let
  macbookHome = macbookConfiguration.config.home-manager.users.sayori;
  fishV = macbookHome.home.file."/Users/sayori/.config/fish/functions/v.fish".source;
  fishZ = macbookHome.home.file."/Users/sayori/.config/fish/functions/z.fish".source;
  zshrc = macbookHome.home.file."./.zshrc".source;
  homeFileNames =
    configuration: builtins.attrNames configuration.config.home-manager.users.sayori.home.file;
  launcherFiles =
    fileNames:
    builtins.filter (
      path: lib.hasSuffix "/functions/v.fish" path || lib.hasSuffix "/functions/z.fish" path
    ) fileNames;
  recorder = pkgs.writeShellScript "editor-launcher-recorder" ''
    printf '%s\n' "$@" > "$TRACE"
  '';
in
assert launcherFiles (homeFileNames nixboxConfiguration) == [ ];
assert launcherFiles (homeFileNames serverConfiguration) == [ ];
pkgs.runCommand "macbook-editor-launchers-check"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.fish
      pkgs.gnugrep
      pkgs.gnused
      pkgs.zsh
    ];
  }
  ''
    bin="$TMPDIR/bin"
    mkdir -p "$bin"
    mkdir -p "$TMPDIR/home" "$TMPDIR/config"
    ln -s ${recorder} "$bin/code"
    ln -s ${recorder} "$bin/zed"

    grep -Fq 'command code .' ${fishV}
    grep -Fq 'command zed .' ${fishZ}
    grep -Fq 'function v()' ${zshrc}
    grep -Fq 'function z()' ${zshrc}
    grep -Fq 'zoxide init zsh --cmd cd' ${zshrc}

    TRACE="$TMPDIR/fish-v-empty" HOME="$TMPDIR/home" XDG_CONFIG_HOME="$TMPDIR/config" \
      PATH="$bin:${pkgs.coreutils}/bin" ${pkgs.fish}/bin/fish --no-config -c 'source ${fishV}; v'
    printf '%s\n' . > "$TMPDIR/fish-v-empty.expected"
    diff -u "$TMPDIR/fish-v-empty.expected" "$TMPDIR/fish-v-empty"

    TRACE="$TMPDIR/fish-z-args" HOME="$TMPDIR/home" XDG_CONFIG_HOME="$TMPDIR/config" \
      PATH="$bin:${pkgs.coreutils}/bin" ${pkgs.fish}/bin/fish --no-config -c 'source ${fishZ}; z --reuse-window "file with space"'
    printf '%s\n' --reuse-window 'file with space' > "$TMPDIR/fish-z-args.expected"
    diff -u "$TMPDIR/fish-z-args.expected" "$TMPDIR/fish-z-args"

    sed -n \
      -e '/^function v()/,/^}/p' \
      -e '/^function z()/,/^}/p' \
      ${zshrc} > "$TMPDIR/launchers.zsh"
    grep -Fq 'function v()' "$TMPDIR/launchers.zsh"
    grep -Fq 'function z()' "$TMPDIR/launchers.zsh"
    ${pkgs.zsh}/bin/zsh -n "$TMPDIR/launchers.zsh"

    TRACE="$TMPDIR/zsh-v-empty" PATH="$bin:${pkgs.coreutils}/bin" \
      ${pkgs.zsh}/bin/zsh -df -c 'source "$1"; v' zsh "$TMPDIR/launchers.zsh"
    printf '%s\n' . > "$TMPDIR/zsh-v-empty.expected"
    diff -u "$TMPDIR/zsh-v-empty.expected" "$TMPDIR/zsh-v-empty"

    TRACE="$TMPDIR/zsh-z-args" PATH="$bin:${pkgs.coreutils}/bin" \
      ${pkgs.zsh}/bin/zsh -df -c 'source "$1"; z --reuse-window "file with space"' zsh "$TMPDIR/launchers.zsh"
    printf '%s\n' --reuse-window 'file with space' > "$TMPDIR/zsh-z-args.expected"
    diff -u "$TMPDIR/zsh-z-args.expected" "$TMPDIR/zsh-z-args"

    touch "$out"
  ''
