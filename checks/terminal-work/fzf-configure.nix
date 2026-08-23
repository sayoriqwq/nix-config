{
  homeManager,
  intentLib,
  lib,
  pkgs,
}:

let
  fzf = import ../../software/fzf {
    inherit intentLib lib;
  };
  configured = intentLib.realize (
    fzf.configure {
      defaultCommand = "fd --type f";
      previewCommand = "bat --color=always --style=plain {}";
    } intentLib.empty
  );
  home = homeManager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = configured.homeModules ++ [
      {
        home = {
          username = "terminal-work-check";
          homeDirectory = "/tmp/terminal-work-check";
          stateVersion = "26.05";
        };
      }
    ];
  };
  failures = lib.debug.runTests {
    testDefaultCommand = {
      expr = home.config.programs.fzf.defaultCommand;
      expected = "fd --type f";
    };
    testPreviewCommand = {
      expr = home.config.programs.fzf.defaultOptions;
      expected = [ "--preview 'bat --color=always --style=plain {}'" ];
    };
  };
in
assert
  lib.debug.throwTestFailures {
    inherit failures;
    description = "fzf.configure contribution tests";
  } == null;
pkgs.runCommand "fzf-configure-contribution" { } ''
  touch "$out"
''
