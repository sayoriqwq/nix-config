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
  macbookLaunchdPath = macbookConfiguration.config.launchd.user.envVariables.PATH or "";
  macbookHomeManagerProfileBin = "${macbookConfiguration.config.home-manager.users.sayori.home.profileDirectory}/bin";
  expectedMacbookLaunchdPath = lib.concatStringsSep ":" [
    macbookHomeManagerProfileBin
    "/run/current-system/sw/bin"
    "/usr/bin"
    "/bin"
    "/usr/sbin"
    "/sbin"
  ];
in
assert lib.assertMsg (hasPackage "nil" macbookPackages)
  "macbook Zed capability must provide the nil Nix language server";
assert lib.assertMsg (hasPackage "nixd" macbookPackages)
  "macbook Zed capability must provide the nixd Nix language server";
assert lib.assertMsg (hasPackage "nil" nixboxPackages)
  "nixbox Zed capability must provide the nil Nix language server";
assert lib.assertMsg (hasPackage "nixd" nixboxPackages)
  "nixbox Zed capability must provide the nixd Nix language server";
assert lib.assertMsg (
  !hasPackage "nil" serverPackages
) "headless server must not receive the Zed Nix language server";
assert lib.assertMsg (
  !hasPackage "nixd" serverPackages
) "headless server must not receive the nixd Nix language server";
assert lib.assertMsg (macbookLaunchdPath == expectedMacbookLaunchdPath)
  "macbook Zed capability must expose only the Home Manager profile, active system generation, and system paths to launchd";
pkgs.runCommand "zed-nix-lsp-policy" { } ''
  touch "$out"
''
