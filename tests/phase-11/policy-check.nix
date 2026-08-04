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

  macbookPackages = macbookConfig.home-manager.users.sayori.home.packages;
  nixboxPackages = nixboxConfig.home-manager.users.sayori.home.packages;
  serverPackages = serverConfig.home-manager.users.sayori.home.packages;

  expectedAdminPackages = [
    "age"
    "sops"
    "ssh-to-age"
  ];

  hostConfigs = [
    macbookConfig
    nixboxConfig
    serverConfig
  ];

  validHostConfig =
    config:
    config.sops.age.sshKeyPaths == [ "/etc/ssh/ssh_host_ed25519_key" ]
    && config.sops.age.keyFile == null
    && !config.sops.age.generateKey
    && config.sops.gnupg.sshKeyPaths == [ ]
    && config.sops.validateSopsFiles
    && config.sops.secrets == { };
in
assert lib.assertMsg (lib.all (
  name: hasPackage name macbookPackages
) expectedAdminPackages) "macbook must provide the approved SOPS/age administration tools";
assert lib.assertMsg (
  lib.all (name: !hasPackage name nixboxPackages) expectedAdminPackages
  && lib.all (name: !hasPackage name serverPackages) expectedAdminPackages
) "nixbox and server must not receive SOPS/age administration tools through Home Manager";
assert lib.assertMsg (lib.all validHostConfig hostConfigs)
  "all hosts must keep host-local SSH-derived SOPS plumbing without placeholder secrets";
pkgs.runCommand "sops-age-policy"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.diffutils
      pkgs.findutils
      pkgs.gnugrep
      pkgs.yq-go
    ];
  }
  ''
    set -euo pipefail

    fail() {
      printf 'sops-age-policy: %s\n' "$*" >&2
      exit 1
    }

    cd ${source}
    config_file=.sops.yaml

    test "$(yq -r '.creation_rules | length' "$config_file")" = 3 ||
      fail ".sops.yaml must contain exactly three host-scoped creation rules"

    if grep -E -q '^[[:space:]]*shamir_threshold:' "$config_file"; then
      fail "host rules must not require multiple identities through Shamir threshold"
    fi

    private_age_marker='AGE-SECRET-KEY-'
    private_pem_marker='-----BEGIN ([A-Z0-9 ]+ )?PRIVATE KEY-----'
    if find ${source} -type f ! -path '*/tests/phase-11/policy-check.nix' -print0 |
      xargs -0 grep -I -E "$private_age_marker|$private_pem_marker"; then
      fail "repository source contains private-key material"
    fi

    check_rule() {
      index="$1"
      host="$2"
      host_recipient="$3"
      actual_recipients="$TMPDIR/$host.actual"
      expected_recipients="$TMPDIR/$host.expected"

      test "$(yq -r ".creation_rules[$index].path_regex" "$config_file")" = "^secrets/$host/[^/]+\\.yaml$" ||
        fail "$host creation rule path is not host-scoped"

      yq -r "explode(.) | .creation_rules[$index].key_groups[0].age[]" "$config_file" | sort -u > "$actual_recipients"
      printf '%s\n%s\n' ${lib.escapeShellArg adminRecipient} "$host_recipient" | sort -u > "$expected_recipients"
      diff -u "$expected_recipients" "$actual_recipients" ||
        fail "$host recipient set is broader or narrower than admin + host"
    }

    check_rule 0 macbook ${lib.escapeShellArg hostRecipients.macbook}
    check_rule 1 nixbox ${lib.escapeShellArg hostRecipients.nixbox}
    check_rule 2 server ${lib.escapeShellArg hostRecipients.server}

    if test -d secrets && find secrets -type f -print -quit | grep -q .; then
      fail "placeholder secrets must not remain after Phase 11 reconciliation"
    fi

    touch "$out"
  ''
