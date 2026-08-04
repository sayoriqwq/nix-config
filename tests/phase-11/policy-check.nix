{
  adminRecipient,
  hostRecipients,
  macbookConfiguration,
  nixboxConfiguration,
  pkgs,
  serverConfiguration,
  source,
}:

let
  inherit (pkgs) lib;
  packageName = package: package.pname or (lib.getName package);
  hasPackage = name: packages: lib.any (package: packageName package == name) packages;

  macbookConfig = macbookConfiguration.config;
  nixboxConfig = nixboxConfiguration.config;
  serverConfig = serverConfiguration.config;

  macbookSecret = macbookConfig.sops.secrets.phase11-demo;
  nixboxSecret = nixboxConfig.sops.secrets.phase11-demo;
  serverSecret = serverConfig.sops.secrets.phase11-demo;

  macbookPackages = macbookConfig.home-manager.users.sayori.home.packages;
  nixboxPackages = nixboxConfig.home-manager.users.sayori.home.packages;
  serverPackages = serverConfig.home-manager.users.sayori.home.packages;

  expectedAdminPackages = [
    "age"
    "sops"
    "ssh-to-age"
  ];

  hostCases = [
    {
      id = "macbook";
      config = macbookConfig;
      secret = macbookSecret;
      expectedGroup = "staff";
      recipient = hostRecipients.macbook;
    }
    {
      id = "nixbox";
      config = nixboxConfig;
      secret = nixboxSecret;
      expectedGroup = nixboxConfig.users.users.sayori.group;
      recipient = hostRecipients.nixbox;
    }
    {
      id = "server";
      config = serverConfig;
      secret = serverSecret;
      expectedGroup = serverConfig.users.users.sayori.group;
      recipient = hostRecipients.server;
    }
  ];

  validHostCase =
    host:
    (
      host.config.sops.age.sshKeyPaths == [ "/etc/ssh/ssh_host_ed25519_key" ]
      && host.config.sops.age.keyFile == null
      && !host.config.sops.age.generateKey
      && host.config.sops.gnupg.sshKeyPaths == [ ]
      && host.config.sops.validateSopsFiles
      && host.secret.path == "/run/secrets/phase11-demo"
      && host.secret.owner == "sayori"
      && host.secret.group == host.expectedGroup
      && host.secret.mode == "0400"
      && host.secret.restartUnits or [ ] == [ ]
      && host.secret.reloadUnits or [ ] == [ ]
    );
in
assert lib.assertMsg (lib.all (
  name: hasPackage name macbookPackages
) expectedAdminPackages) "macbook must provide the approved SOPS/age administration tools";
assert lib.assertMsg (
  lib.all (name: !hasPackage name nixboxPackages) expectedAdminPackages
  && lib.all (name: !hasPackage name serverPackages) expectedAdminPackages
) "nixbox and server must not receive SOPS/age administration tools through Home Manager";
assert lib.assertMsg (lib.all validHostCase hostCases)
  "all hosts must use one host SSH identity and the phase11-demo runtime contract";
assert lib.assertMsg (
  lib.length (lib.unique (map (host: toString host.secret.sopsFile) hostCases)) == 3
) "each host must use a distinct SOPS file";
pkgs.runCommand "phase11-sops-policy"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.diffutils
      pkgs.findutils
      pkgs.gnugrep
      pkgs.jq
      pkgs.sops
      pkgs.yq-go
    ];
  }
  ''
    set -euo pipefail

    fail() {
      printf 'phase11-sops-policy: %s\n' "$*" >&2
      exit 1
    }

    cd ${source}
    admin_recipient=${lib.escapeShellArg adminRecipient}
    config_file=.sops.yaml

    test "$(yq -r '.creation_rules | length' "$config_file")" = 3 ||
      fail ".sops.yaml must contain exactly three host-scoped creation rules"

    if yq -e '.. | select(has("shamir_threshold"))' "$config_file" >/dev/null; then
      fail "Phase 11 must not require multiple identities through Shamir threshold"
    fi

    private_age_marker='AGE-SECRET-KEY-'
    private_pem_marker='-----BEGIN ([A-Z0-9 ]+ )?PRIVATE KEY-----'
    if find ${source} -type f ! -path '*/tests/phase-11/policy-check.nix' -print0 |
      xargs -0 grep -I -E "$private_age_marker|$private_pem_marker"; then
      fail "repository source contains private-key material"
    fi

    if find ${source}/secrets -type f ! -name '*.yaml' -print -quit | grep -q .; then
      fail "Phase 11 secrets directory contains an unexpected plaintext/file format"
    fi

    check_host() {
      host="$1"
      host_recipient="$2"
      secret_file=secrets/"$host"/phase11-demo.yaml
      actual_recipients="$TMPDIR/$host.actual"
      expected_recipients="$TMPDIR/$host.expected"

      test -f "$secret_file" || fail "$host encrypted demo is missing"
      test "$(yq -r '."phase11-demo"' "$secret_file")" != "null" ||
        fail "$host encrypted demo key is missing"
      yq -r '."phase11-demo"' "$secret_file" | grep -q '^ENC\[' ||
        fail "$host demo value is not encrypted"
      yq -r '.sops.mac' "$secret_file" | grep -q '^ENC\[' ||
        fail "$host SOPS MAC is not encrypted"

      yq -r '.sops.age[].recipient' "$secret_file" | sort -u > "$actual_recipients"
      printf '%s\n%s\n' "$admin_recipient" "$host_recipient" | sort -u > "$expected_recipients"
      diff -u "$expected_recipients" "$actual_recipients" ||
        fail "$host recipient set is broader or narrower than admin + host"
      test "$(wc -l < "$actual_recipients" | tr -d ' ')" = 2 ||
        fail "$host encrypted demo must have exactly two recipients"

      SOPS_CONFIG=/dev/null sops filestatus "$secret_file" | jq -e '.encrypted == true' >/dev/null ||
        fail "$host demo is not recognized as an encrypted SOPS file"
    }

    check_host macbook ${lib.escapeShellArg hostRecipients.macbook}
    check_host nixbox ${lib.escapeShellArg hostRecipients.nixbox}
    check_host server ${lib.escapeShellArg hostRecipients.server}

    touch "$out"
  ''
