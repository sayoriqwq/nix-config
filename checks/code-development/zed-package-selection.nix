{
  darwinHomeManager,
  darwinPkgs,
  linuxHomeManager,
  linuxPkgs,
  serverConfiguration,
  username,
}:

let
  zed = import ../../software/zed;
  makeHome =
    {
      homeManager,
      homeDirectory,
      pkgs,
      username,
    }:
    homeManager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = zed.guiEditor.homeModules ++ [
        {
          home = {
            inherit homeDirectory username;
            stateVersion = "26.05";
          };
        }
      ];
    };
  darwinHome = makeHome {
    homeManager = darwinHomeManager;
    homeDirectory = "/tmp/zed-package-selection-darwin";
    pkgs = darwinPkgs;
    username = "zed-package-selection-darwin";
  };
  linuxHome = makeHome {
    homeManager = linuxHomeManager;
    homeDirectory = "/tmp/zed-package-selection-linux";
    pkgs = linuxPkgs;
    username = "zed-package-selection-linux";
  };
  darwinZed = darwinPkgs.callPackage ../../software/zed/package.nix { };
  linuxZed = linuxPkgs.zed-editor;
  packagePaths = home: map toString home.config.home.packages;
  settingsText =
    home:
    builtins.readFile (
      (builtins.head (
        builtins.filter (
          seed: darwinPkgs.lib.hasSuffix "/settings.json" seed.target
        ) home.config.sayori.editors.seedFiles
      )).baseline
    );
  zedPackagePaths =
    paths: builtins.filter (path: builtins.match ".*zed-(editor|preview).*" path != null) paths;
  serverPackagePaths = map toString (
    serverConfiguration.config.environment.systemPackages
    ++ serverConfiguration.config.home-manager.users.${username}.home.packages
  );
  failures = darwinPkgs.lib.debug.runTests {
    testDarwinDoesNotInstallStoreZed = {
      expr = zedPackagePaths (packagePaths darwinHome);
      expected = [ ];
    };
    testDarwinDistribution = {
      expr = darwinZed.passthru.zedDistribution;
      expected = "official-preview-binary";
    };
    testDarwinAutoUpdateEnabled = {
      expr = darwinPkgs.lib.hasInfix ''"auto_update": true'' (settingsText darwinHome);
      expected = true;
    };
    testLinuxAutoUpdateDisabled = {
      expr = darwinPkgs.lib.hasInfix ''"auto_update": false'' (settingsText linuxHome);
      expected = true;
    };
    testLinuxUsesReleaseStable = {
      expr = zedPackagePaths (packagePaths linuxHome);
      expected = [ (toString linuxZed) ];
    };
    testDarwinEditorCommand = {
      expr = {
        inherit (darwinHome.config.home.sessionVariables) EDITOR VISUAL;
      };
      expected = {
        EDITOR = "zed --wait";
        VISUAL = "zed --wait";
      };
    };
    testLinuxEditorCommand = {
      expr = {
        inherit (linuxHome.config.home.sessionVariables) EDITOR VISUAL;
      };
      expected = {
        EDITOR = "zeditor --wait";
        VISUAL = "zeditor --wait";
      };
    };
    testServerDoesNotSelectZed = {
      expr = zedPackagePaths serverPackagePaths;
      expected = [ ];
    };
  };
in
assert
  darwinPkgs.lib.debug.throwTestFailures {
    inherit failures;
    description = "Zed platform package selection tests";
  } == null;
darwinPkgs.runCommand "zed-platform-package-selection" { } ''
  touch "$out"
''
