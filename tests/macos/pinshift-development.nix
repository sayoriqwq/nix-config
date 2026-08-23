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
  pinshiftPackages =
    home: builtins.filter (package: lib.getName package == "pinshift") home.home.packages;
  macbookPinshiftPackages = pinshiftPackages macbookHome;
  fixture = pkgs.writeTextFile {
    name = "pinshift";
    destination = "/bin/pinshift";
    executable = true;
    text = ''
      #!${lib.getExe pkgs.fish}
      printf '%s\n' $argv
    '';
  };
in
assert builtins.length macbookPinshiftPackages == 1;
assert pinshiftPackages nixboxHome == [ ];
assert pinshiftPackages serverHome == [ ];
pkgs.runCommand "macbook-pinshift-development-check"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.gnugrep
    ];
  }
  ''
    launcher=${builtins.head macbookPinshiftPackages}/bin/pinshift
    export HOME="$TMPDIR/home"
    export XDG_CONFIG_HOME="$TMPDIR/config"
    mkdir -p "$HOME" "$XDG_CONFIG_HOME"

    PINSHIFT_CHECKOUT=${fixture} "$launcher" start "two words" > actual
    printf '%s\n' start "two words" > expected
    diff -u expected actual

    if PINSHIFT_CHECKOUT="$TMPDIR/missing" "$launcher" help > missing.out 2> missing.err; then
      echo "The launcher unexpectedly accepted a missing checkout." >&2
      exit 1
    fi
    grep -Fq 'Pinshift checkout entrypoint is unavailable' missing.err

    touch "$out"
  ''
