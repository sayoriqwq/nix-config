{ lib }:

let
  intentLib = import ../lib.nix;
  software = {
    fish = import ../../software/fish { inherit intentLib; };
    git = import ../../software/git { inherit intentLib; };
    lazygit = import ../../software/lazygit { inherit intentLib; };
    nil = import ../../software/nil { inherit intentLib; };
    nixd = import ../../software/nixd { inherit intentLib; };
    zed = import ../../software/zed { inherit intentLib; };
  };
in
intentLib.realize (
  lib.pipe intentLib.empty [
    software.fish.interactiveShell
    software.zed.guiEditor
    software.zed.fishQuickCommand
    software.git.versionControl
    software.lazygit.gitTui
    software.nil.nixLanguageServer
    software.nixd.nixLanguageServer
    (software.zed.addTask {
      name = "LazyGit";
      command = "lazygit";
    })
  ]
)
