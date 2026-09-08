{ lib }:

let
  compose = import ../lib.nix { inherit lib; };
  software = {
    fish = import ../../software/fish;
    git = import ../../software/git;
    lazygit = import ../../software/lazygit;
    nil = import ../../software/nil;
    nixd = import ../../software/nixd;
    zed = import ../../software/zed;
  };
in
compose [
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
