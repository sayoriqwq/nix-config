{
  flakeInputs,
  flakeOutputs,
  lib,
  macbookConfiguration,
  nixboxConfiguration,
  pkgs,
  serverConfiguration,
  source,
}:

let
  homePackages = configuration: configuration.config.home-manager.users.sayori.home.packages;
  packageRelease = package: package.passthru.zedRelease or null;
  selectedZed = packages: lib.findFirst (package: packageRelease package != null) null packages;

  macbookZed = selectedZed (homePackages macbookConfiguration);
  nixboxZed = selectedZed (homePackages nixboxConfiguration);
  serverZed = selectedZed (homePackages serverConfiguration);

  darwinOutput = flakeOutputs.packages.aarch64-darwin.zed-nightly;
  linuxOutput = flakeOutputs.packages.x86_64-linux.zed-nightly;
  darwinUpdater = flakeOutputs.apps.aarch64-darwin.sync-zed-nightly;
  linuxUpdater = flakeOutputs.apps.x86_64-linux.sync-zed-nightly;
  expectedRelease = "1.15.0+nightly.3083.66ed3027b8ca7fed0feeee91d1ce6346ccd4ac39";

  lock = builtins.fromJSON (builtins.readFile (source + "/flake.lock"));
  rootInputs = lock.nodes.${lock.root}.inputs;
  implementationSources = lib.concatMapStringsSep "\n" builtins.readFile [
    (source + "/flake.nix")
    (source + "/modules/darwin/base.nix")
    (source + "/modules/capabilities/zed-editor/nixos.nix")
    (source + "/modules/home/desktop/editors/zed/default.nix")
    (source + "/packages/zed-nightly/default.nix")
  ];
  updaterSource = builtins.readFile (source + "/packages/zed-nightly/update.sh");
in
assert lib.assertMsg (
  !(flakeInputs ? zed)
) "the root Flake must not retain the Zed source-Flake input";
assert lib.assertMsg (
  !(rootInputs ? zed)
) "flake.lock must not retain the Zed source-Flake root input";
assert lib.assertMsg (
  macbookZed != null && nixboxZed != null
) "both workstations must select the owner-local official Zed binary package";
assert lib.assertMsg (serverZed == null) "the headless server must not select a Zed package";
assert lib.assertMsg (
  macbookZed.outPath == darwinOutput.outPath && nixboxZed.outPath == linuxOutput.outPath
) "host package selection and explicit Flake package outputs must share one owner";
assert lib.assertMsg (
  packageRelease macbookZed == expectedRelease && packageRelease nixboxZed == expectedRelease
) "both platforms must pin the same exact official Nightly release identity";
assert lib.assertMsg (
  darwinUpdater.type == "app"
  && linuxUpdater.type == "app"
  && lib.hasSuffix "/bin/sync-zed-nightly" darwinUpdater.program
  && lib.hasSuffix "/bin/sync-zed-nightly" linuxUpdater.program
) "both workstation systems must expose the same maintainer-run Zed sync entrypoint";
assert lib.assertMsg (
  macbookZed.passthru.zedDistribution == "official-nightly-binary"
  && nixboxZed.passthru.zedDistribution == "official-nightly-binary"
) "Zed must be packaged only from official prebuilt Nightly artifacts";
assert lib.assertMsg (
  !(lib.hasInfix "inputs.zed.packages" implementationSources)
  && !(lib.hasInfix "zed.cachix.org" implementationSources)
  && !(lib.hasInfix "vendorCargoDeps" implementationSources)
  && !(lib.hasInfix "/nightly/latest/" implementationSources)
) "the production Zed graph must not retain source-Flake, Cachix, or Crane vendor paths";
assert lib.assertMsg (
  lib.hasInfix "nix store prefetch-file" updaterSource
  && lib.hasInfix "arch=aarch64&os=macos" updaterSource
  && lib.hasInfix "arch=x86_64&os=linux" updaterSource
) "the maintainer-run sync must verify and hash both official workstation artifacts";
pkgs.runCommand "zed-binary-package-policy" { } ''
  touch "$out"
''
