{
  pkgs,
  username,
}:

let
  adminHome = "/Users/${username}";
  keyDirectory = "${adminHome}/Library/Application Support/sops/age";
  keyFile = "${keyDirectory}/keys.txt";
in
pkgs.writeShellApplication {
  name = "phase11-init-admin-key";
  runtimeInputs = [ pkgs.age ];
  text = ''
    fail() {
      printf 'phase11-init-admin-key: %s\n' "$*" >&2
      exit 1
    }

    if test "$#" -ne 0; then
      fail "accepts no paths or extra arguments"
    fi

    if test "$(/usr/bin/uname -s)" != "Darwin"; then
      fail "must run on macbook"
    fi

    if test "$(/usr/bin/id -un)" != ${pkgs.lib.escapeShellArg username}; then
      fail "must run as ${username}, never through sudo"
    fi

    key_directory=${pkgs.lib.escapeShellArg keyDirectory}
    key_file=${pkgs.lib.escapeShellArg keyFile}

    for path_component in \
      ${pkgs.lib.escapeShellArg "${adminHome}/Library"} \
      ${pkgs.lib.escapeShellArg "${adminHome}/Library/Application Support"} \
      ${pkgs.lib.escapeShellArg "${adminHome}/Library/Application Support/sops"} \
      "$key_directory" \
      "$key_file"; do
      if test -L "$path_component"; then
        fail "refuses symlinked key paths"
      fi
    done

    if test -e "$key_file"; then
      fail "administrator identity already exists; refusing to overwrite it"
    fi

    umask 077
    /usr/bin/install -d -m 0700 "$key_directory"
    test "$(/usr/bin/stat -f '%Su' "$key_directory")" = ${pkgs.lib.escapeShellArg username} ||
      fail "identity directory has an unexpected owner"
    test "$(/usr/bin/stat -f '%Lp' "$key_directory")" = "700" ||
      fail "identity directory must have mode 0700"

    age-keygen -o "$key_file" >/dev/null 2>&1

    test "$(/usr/bin/stat -f '%Su' "$key_file")" = ${pkgs.lib.escapeShellArg username} ||
      fail "generated identity has an unexpected owner"
    test "$(/usr/bin/stat -f '%Lp' "$key_file")" = "600" ||
      fail "generated identity must have mode 0600"

    public_recipient="$(age-keygen -y "$key_file")"
    printf 'phase11-init-admin-key: public-recipient=%s\n' "$public_recipient"
    printf 'phase11-init-admin-key: NEXT: create and verify one encrypted offline backup before activation\n'
  '';
}
