{
  homeManager,
  intentLib,
  lib,
  pkgs,
}:

let
  makeHome =
    name: modules:
    homeManager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = modules ++ [
        {
          home = {
            username = name;
            homeDirectory = "/tmp/${name}";
            stateVersion = "26.05";
          };
        }
      ];
    };
  fzf = import ../../software/fzf {
    inherit intentLib lib;
  };
  zsh = import ../../software/zsh { inherit intentLib; };
  fzfHome = makeHome "shortcut-reference-fzf" (intentLib.realize (fzf.fuzzySelector intentLib.empty))
  .homeModules;
  zshHome = makeHome "shortcut-reference-zsh" (intentLib.realize (
    zsh.compatibilityShell intentLib.empty
  )).homeModules;
  guideHome = makeHome "shortcut-reference-guide" [
    ../../modules/home/capabilities/shortcut-reference.nix
    {
      sayori.shortcuts = [
        {
          scope = "Later|scope";
          keys = "B\nC";
          action = "line\nnext";
          owner = "owner|two";
          order = 20;
        }
        {
          scope = "Earlier";
          keys = "A";
          action = "first";
          owner = "owner-one";
          order = 10;
        }
      ];
    }
  ];
  guide = guideHome.config.xdg.dataFile."nix-config/SHORTCUTS.md";
  expectedGuide = ''
    # 快捷键与快速入口

    > 本表由当前 Host 最终选择的 Software 声明生成。配置事实仍归对应 Software 所有。

    | 范围 | 快捷键或入口 | 行为 | 所有者 |
    | --- | --- | --- | --- |
    | Earlier | `A` | first | owner-one |
    | Later\|scope | `B C` | line next | owner\|two |
  '';
  failures = lib.debug.runTests {
    testFzfStandaloneContribution = {
      expr = map (shortcut: shortcut.owner) fzfHome.config.sayori.shortcuts;
      expected = [
        "fzf"
        "fzf"
      ];
    };
    testZshStandaloneContribution = {
      expr = map (shortcut: shortcut.owner) zshHome.config.sayori.shortcuts;
      expected = [ "zsh" ];
    };
    testGuideTarget = {
      expr = guide.target;
      expected = ".local/share/nix-config/SHORTCUTS.md";
    };
    testGuideText = {
      expr = guide.text;
      expected = expectedGuide;
    };
  };
in
assert
  lib.debug.throwTestFailures {
    inherit failures;
    description = "shortcut reference tests";
  } == null;
pkgs.runCommand "shortcut-reference" { } ''
  cmp ${guide.source} ${pkgs.writeText "shortcut-reference-expected.md" expectedGuide}
  touch "$out"
''
