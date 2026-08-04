{
  macbookConfiguration,
  nixboxConfiguration,
  pkgs,
  serverConfiguration,
}:

let
  inherit (pkgs) lib;
  packageName = package: package.pname or (lib.getName package);
  hasPackage = name: packages: lib.any (package: packageName package == name) packages;

  homePackages = configuration: configuration.config.home-manager.users.sayori.home.packages;
  macbookPackages = homePackages macbookConfiguration;
  nixboxPackages = homePackages nixboxConfiguration;
  serverPackages = homePackages serverConfiguration;
in
assert lib.assertMsg (hasPackage "nil" macbookPackages)
  "macbook Zed capability must provide the nil Nix language server";
assert lib.assertMsg (hasPackage "nil" nixboxPackages)
  "nixbox Zed capability must provide the nil Nix language server";
assert lib.assertMsg (
  !hasPackage "nil" serverPackages
) "headless server must not receive the Zed Nix language server";
pkgs.runCommand "zed-nix-lsp-policy" { } ''
  touch "$out"
''
