{
  homeConfiguration,
  pkgs,
}:

let
  inherit (pkgs) lib;
  packageName = package: package.pname or (lib.getName package);
  postgresqlPackages = lib.filter (
    package: lib.hasInfix "postgresql" (lib.toLower (packageName package))
  ) homeConfiguration.home.packages;
  postgresqlSessionPaths = lib.filter (
    path: lib.hasInfix "postgresql" (lib.toLower path)
  ) homeConfiguration.home.sessionPath;
  postgresqlStatePaths = lib.filter (
    entry: lib.hasInfix "postgresql" (lib.toLower entry.path)
  ) homeConfiguration.sayori.statePaths;
in
assert lib.assertMsg (
  postgresqlPackages == [ ]
) "macbook must not provide a global PostgreSQL package";
assert lib.assertMsg (
  postgresqlSessionPaths == [ ]
) "macbook must not expose a global PostgreSQL compatibility PATH";
assert lib.assertMsg (
  postgresqlStatePaths == [ ]
) "macbook must not track retired PostgreSQL mutable state";
pkgs.runCommand "macbook-postgresql-retirement" { } ''
  touch "$out"
''
