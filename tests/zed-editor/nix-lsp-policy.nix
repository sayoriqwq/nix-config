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
  macbookLaunchdPath = macbookConfiguration.config.launchd.user.envVariables.PATH;
  macbookHomeDirectory = macbookConfiguration.config.home-manager.users.sayori.home.homeDirectory;
  macbookHomeManagerProfileBin = "${macbookConfiguration.config.home-manager.users.sayori.home.profileDirectory}/bin";
  macbookHomeLocalBin = "${macbookHomeDirectory}/.local/bin";
  macbookLegacyUserProfileBin = "${macbookHomeDirectory}/.nix-profile/bin";
  rootBootstrapProfileBin = "/nix/var/nix/profiles/default/bin";
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
assert lib.assertMsg
  (lib.hasPrefix "${macbookHomeManagerProfileBin}:${macbookHomeLocalBin}:" macbookLaunchdPath)
  "macbook Zed launchd PATH must prefer the Home Manager profile and user compatibility path";
assert lib.assertMsg (
  !lib.hasInfix macbookLegacyUserProfileBin macbookLaunchdPath
) "macbook Zed launchd PATH must not expose the mutable legacy user Nix profile";
assert lib.assertMsg (
  !lib.hasInfix rootBootstrapProfileBin macbookLaunchdPath
) "macbook Zed launchd PATH must not expose the root bootstrap Nix profile";
pkgs.runCommand "zed-nix-lsp-policy" { } ''
  touch "$out"
''
