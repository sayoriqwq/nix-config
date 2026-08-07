{
  lib,
  macbookConfiguration,
  nixboxConfiguration,
  pkgs,
  serverConfiguration,
}:

let
  macbookHome = macbookConfiguration.config.home-manager.users.sayori;
  nixboxHome = nixboxConfiguration.config.home-manager.users.sayori;
  serverHome = serverConfiguration.config.home-manager.users.sayori;
  zshrc = macbookHome.home.file."./.zshrc".source;
  homeFileNames = home: builtins.attrNames home.home.file;
  fishFunctionSource =
    home: name:
    let
      path = builtins.head (
        builtins.filter (candidate: lib.hasSuffix ("/functions/${name}.fish") candidate) (
          builtins.attrNames home.home.file
        )
      );
    in
    (builtins.getAttr path home.home.file).source;
  macbookFishV = fishFunctionSource macbookHome "v";
  macbookFishZ = fishFunctionSource macbookHome "z";
  nixboxFishZ = nixboxHome.programs.fish.functions.z;
  launcherFiles =
    fileNames:
    builtins.filter (
      path: lib.hasSuffix "/functions/v.fish" path || lib.hasSuffix "/functions/z.fish" path
    ) fileNames;
  zshFiles = fileNames: builtins.filter (path: lib.hasSuffix "/.zshrc" path) fileNames;
  recorder = pkgs.writeShellScript "editor-launcher-recorder" ''
    printf '%s\n' "$@" > "$TRACE"
  '';
in
assert lib.any (pkg: lib.getName pkg == "vscode") macbookHome.home.packages;
assert !(lib.any (pkg: lib.getName pkg == "vscode") nixboxHome.home.packages);
assert builtins.hasAttr "v" macbookHome.programs.fish.functions;
assert builtins.hasAttr "z" macbookHome.programs.fish.functions;
assert !(builtins.hasAttr "v" nixboxHome.programs.fish.functions);
assert builtins.hasAttr "z" nixboxHome.programs.fish.functions;
assert launcherFiles (homeFileNames macbookHome) != [ ];
assert launcherFiles (homeFileNames nixboxHome) != [ ];
assert launcherFiles (homeFileNames serverHome) == [ ];
assert lib.any (path: lib.hasSuffix "/functions/v.fish" path) (homeFileNames macbookHome);
assert !(lib.any (path: lib.hasSuffix "/functions/v.fish" path) (homeFileNames nixboxHome));
assert lib.any (path: lib.hasSuffix "/functions/z.fish" path) (homeFileNames macbookHome);
assert lib.any (path: lib.hasSuffix "/functions/z.fish" path) (homeFileNames nixboxHome);
assert zshFiles (homeFileNames nixboxHome) == [ ];
pkgs.runCommand "editor-capability-launchers-check"
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

            grep -Fq 'command code .' ${macbookFishV}
            grep -Fq 'command zed .' ${macbookFishZ}
        cat > "$TMPDIR/nixbox-z.fish" <<'EOF'
    function z
    ${nixboxFishZ}
    end
    EOF
            grep -Fq 'command zed .' "$TMPDIR/nixbox-z.fish"
            grep -Fq 'function v()' ${zshrc}
            grep -Fq 'function z()' ${zshrc}
            grep -Fq 'zoxide init zsh --cmd cd' ${zshrc}

            TRACE="$TMPDIR/fish-v-empty" HOME="$TMPDIR/home" XDG_CONFIG_HOME="$TMPDIR/config" \
              PATH="$bin:${pkgs.coreutils}/bin" ${pkgs.fish}/bin/fish --no-config -c 'source ${macbookFishV}; v'
            printf '%s\n' . > "$TMPDIR/fish-v-empty.expected"
            diff -u "$TMPDIR/fish-v-empty.expected" "$TMPDIR/fish-v-empty"

        TRACE="$TMPDIR/fish-z-args" HOME="$TMPDIR/home" XDG_CONFIG_HOME="$TMPDIR/config" \
          PATH="$bin:${pkgs.coreutils}/bin" ${pkgs.fish}/bin/fish --no-config -c 'source $argv[1]; z --reuse-window "file with space"' "$TMPDIR/nixbox-z.fish"
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
