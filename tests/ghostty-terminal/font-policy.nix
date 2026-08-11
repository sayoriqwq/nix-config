{
  lib,
  macbookConfiguration,
  nixboxConfiguration,
  pkgs,
  serverConfiguration,
  username,
}:

let
  packageName = package: package.pname or (lib.getName package);
  packageCount =
    expected: packages:
    builtins.length (builtins.filter (package: packageName package == packageName expected) packages);

  macbookConfig = macbookConfiguration.config;
  nixboxConfig = nixboxConfiguration.config;
  serverConfig = serverConfiguration.config;

  macbookHome = macbookConfig.home-manager.users.${username};
  nixboxHome = nixboxConfig.home-manager.users.${username};
  serverHome = serverConfig.home-manager.users.${username};

  macbookFont = macbookConfiguration.pkgs.maple-mono.NF-CN;
  nixboxFont = nixboxConfiguration.pkgs.maple-mono.NF-CN;
  serverFont = serverConfiguration.pkgs.maple-mono.NF-CN;
in
assert lib.assertMsg (
  nixboxHome.programs.ghostty.settings."font-family" == [ "Maple Mono NF CN" ]
) "nixbox Ghostty must keep the shared Maple Mono NF CN font-family";
assert lib.assertMsg (
  packageCount nixboxFont nixboxHome.home.packages == 1
) "nixbox Ghostty capability must provide exactly one MapleMono-NF-CN package";
assert lib.assertMsg nixboxHome.fonts.fontconfig.enable
  "nixbox Home Manager must expose the Ghostty font through user fontconfig";
assert lib.assertMsg
  (builtins.hasAttr "fontconfig/conf.d/10-hm-fonts.conf" nixboxHome.xdg.configFile)
  "nixbox Home Manager must generate its font-package fontconfig entry";
assert lib.assertMsg (
  packageCount nixboxFont nixboxConfig.fonts.packages == 0
) "nixbox must keep the Ghostty font in Home Manager rather than NixOS system fonts";
assert lib.assertMsg (
  packageCount serverFont serverHome.home.packages == 0
) "server Home Manager must not install the workstation-only Ghostty font";
assert lib.assertMsg (
  packageCount serverFont serverConfig.fonts.packages == 0
) "server system fonts must not install the workstation-only Ghostty font";
assert lib.assertMsg (
  !serverHome.programs.ghostty.enable
) "server must not enable the workstation-only Ghostty capability";
assert lib.assertMsg (
  packageCount macbookFont macbookConfig.fonts.packages == 1
) "macbook nix-darwin must remain the sole owner of one MapleMono-NF-CN package";
assert lib.assertMsg (
  packageCount macbookFont macbookHome.home.packages == 0
) "macbook Home Manager must not duplicate the nix-darwin font package";
pkgs.runCommand "ghostty-terminal-font-policy-check" { } ''
  touch "$out"
''
