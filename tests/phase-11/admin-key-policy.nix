{
  adminKeyInit,
  pkgs,
}:

pkgs.runCommand "phase11-admin-key-policy"
  {
    nativeBuildInputs = [
      pkgs.age
      pkgs.gnugrep
    ];
  }
  ''
    script=${adminKeyInit}/bin/phase11-init-admin-key

    grep -F 'accepts no paths or extra arguments' "$script"
    grep -F 'must run as sayori, never through sudo' "$script"
    grep -F 'refuses symlinked key paths' "$script"
    grep -F 'refusing to overwrite it' "$script"
    grep -F '/Users/sayori/Library/Application Support/sops/age/keys.txt' "$script"
    grep -F "/usr/bin/stat -f '%Su'" "$script"
    grep -F "/usr/bin/stat -f '%Lp'" "$script"
    grep -F '/usr/bin/install -d -m 0700' "$script"
    grep -F 'public-recipient=%s' "$script"

    if grep -F 'cat "$key_file"' "$script"; then
      echo 'phase11-admin-key-policy: helper must not print private identity content' >&2
      exit 1
    fi

    test_directory="$TMPDIR/phase11-admin-age"
    test_identity="$test_directory/keys.txt"
    /usr/bin/install -d -m 0700 "$test_directory"
    test "$(/usr/bin/stat -f '%Lp' "$test_directory")" = 700
    age-keygen -o "$test_identity" >/dev/null 2>&1
    test "$(/usr/bin/stat -f '%Su' "$test_identity")" = "$(/usr/bin/id -un)"
    test "$(/usr/bin/stat -f '%Lp' "$test_identity")" = 600
    age-keygen -y "$test_identity" | grep -q '^age1'
    rm -f "$test_identity"

    touch "$out"
  ''
