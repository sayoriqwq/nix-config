{
  darwinHomeManager,
  darwinPkgs,
  intentLib,
  linuxHomeManager,
  linuxPkgs,
  serverConfiguration,
  username,
}:

let
  zed = import ../../software/zed {
    inherit intentLib;
  };
  configured = intentLib.realize (zed.guiEditor intentLib.empty);
  makeHome =
    {
      homeManager,
      homeDirectory,
      pkgs,
      username,
    }:
    homeManager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = configured.homeModules ++ [
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
  zedPackagePaths =
    paths: builtins.filter (path: builtins.match ".*zed-(editor|preview).*" path != null) paths;
  serverPackagePaths = map toString (
    serverConfiguration.config.environment.systemPackages
    ++ serverConfiguration.config.home-manager.users.${username}.home.packages
  );
  failures = darwinPkgs.lib.debug.runTests {
    testDarwinUsesOfficialPreview = {
      expr = zedPackagePaths (packagePaths darwinHome);
      expected = [ (toString darwinZed) ];
    };
    testDarwinDistribution = {
      expr = darwinZed.passthru.zedDistribution;
      expected = "official-preview-binary";
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
