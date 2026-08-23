{ lib }:

let
  intentLib = import ../lib.nix;
  software = {
    git = import ../../software/git { inherit intentLib; };
    lazygit = import ../../software/lazygit { inherit intentLib; };
    nil = import ../../software/nil { inherit intentLib; };
    nixd = import ../../software/nixd { inherit intentLib; };
    zed = import ../../software/zed { inherit intentLib; };
  };
in
intentLib.realize (
  lib.pipe intentLib.empty [
    software.zed.guiEditor
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
