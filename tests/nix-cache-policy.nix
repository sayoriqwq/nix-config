{
  lib,
  nixboxConfiguration,
  pkgs,
  serverConfiguration,
  source,
}:

let
  serverSettings = serverConfiguration.config.nix.settings;
  nixboxSettings = nixboxConfiguration.config.nix.settings;

  serverSubstituters = serverSettings.substituters;
  nixboxSubstituters = nixboxSettings.substituters;
  serverExtraSubstituters = serverSettings.extra-substituters or [ ];
  nixboxExtraSubstituters = nixboxSettings.extra-substituters or [ ];

  serverExpected = [
    "https://cache.nixos.org?priority=40"
    "https://mirrors.ustc.edu.cn/nix-channels/store?priority=50"
  ];
  nixboxExpected = [
    "https://mirrors.ustc.edu.cn/nix-channels/store?priority=30"
    "https://cache.nixos.org?priority=40"
  ];

  normalize = url: lib.removeSuffix "/" (builtins.head (lib.splitString "?" url));
  hasNoDuplicates = urls: builtins.length urls == builtins.length (lib.unique (map normalize urls));
  sharedBase = builtins.readFile (source + "/modules/nixos/base.nix");
in
assert lib.assertMsg (
  serverSubstituters == serverExpected
) "server must prefer cache.nixos.org and retain USTC only as a lower-priority fallback";
assert lib.assertMsg (
  nixboxSubstituters == nixboxExpected
) "nixbox must prefer USTC and retain cache.nixos.org as the fallback";
assert lib.assertMsg (hasNoDuplicates (
  serverSubstituters ++ serverExtraSubstituters
)) "server effective substituters must not contain duplicate normalized cache URLs";
assert lib.assertMsg (hasNoDuplicates (
  nixboxSubstituters ++ nixboxExtraSubstituters
)) "nixbox effective substituters must not contain duplicate normalized cache URLs";
assert lib.assertMsg (
  serverExtraSubstituters == [ ]
) "server must not inherit capability-specific extra substituters";
assert lib.assertMsg (
  nixboxExtraSubstituters == [ "https://zed.cachix.org" ]
) "this cache-only issue must preserve the existing nixbox Zed Cachix seam";
assert lib.assertMsg (
  !(lib.hasInfix "mirrors.ustc.edu.cn" sharedBase) && !(lib.hasInfix "cache.nixos.org" sharedBase)
) "the shared NixOS base must not own per-host cache policy";
pkgs.runCommand "nix-cache-policy" { } ''
  touch "$out"
''
