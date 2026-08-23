{
  lib,
  macbookConfiguration,
  nixboxConfiguration,
  pkgs,
  serverConfiguration,
  username,
}:

let
  homePackages = configuration: configuration.config.home-manager.users.${username}.home.packages;
  pinshiftPackages =
    configuration:
    builtins.filter (package: lib.getName package == "pinshift") (homePackages configuration);
  macbookPinshiftPackages = pinshiftPackages macbookConfiguration;
  nixboxPinshiftPackages = pinshiftPackages nixboxConfiguration;
  serverPinshiftPackages = pinshiftPackages serverConfiguration;
  macbookPinshift = lib.findFirst (_: true) null macbookPinshiftPackages;
  forwardingTarget = pkgs.writeTextFile {
    name = "pinshift-forwarding-target";
    destination = "/bin/pinshift";
    executable = true;
    text = ''
      #!${lib.getExe pkgs.fish}
      printf '%s\n' $argv > "$PINSHIFT_CAPTURE"
    '';
  };
  failures = lib.debug.runTests {
    testMacbookHasPinshiftEntrypoint = {
      expr = builtins.length macbookPinshiftPackages;
      expected = 1;
    };
    testNixboxHasNoPinshiftEntrypoint = {
      expr = nixboxPinshiftPackages;
      expected = [ ];
    };
    testServerHasNoPinshiftEntrypoint = {
      expr = serverPinshiftPackages;
      expected = [ ];
    };
  };
in
assert
  lib.debug.throwTestFailures {
    inherit failures;
    description = "Pinshift host selection tests";
  } == null;
pkgs.runCommand "macbook-pinshift-development"
  {
    nativeBuildInputs = [ macbookPinshift ];
  }
  ''
    export HOME="$TMPDIR/home"
    export PINSHIFT_CAPTURE="$TMPDIR/forwarded-arguments"
    mkdir -p "$HOME"
    PINSHIFT_CHECKOUT=${forwardingTarget} pinshift alpha "two words" "--flag=value"

    printf '%s\n' alpha "two words" "--flag=value" > "$TMPDIR/expected-arguments"
    cmp "$TMPDIR/expected-arguments" "$PINSHIFT_CAPTURE"

    missing_status=0
    PINSHIFT_CHECKOUT="$TMPDIR/missing-checkout" pinshift \
      > "$TMPDIR/missing-stdout" \
      2> "$TMPDIR/missing-stderr" \
      || missing_status=$?

    test "$missing_status" -eq 127
    grep -Fq "Pinshift checkout entrypoint is unavailable" "$TMPDIR/missing-stderr"
    grep -Fq "$TMPDIR/missing-checkout/bin/pinshift" "$TMPDIR/missing-stderr"

    touch "$out"
  ''
