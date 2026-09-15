{ lib }:

let
  compose = import ./lib.nix { inherit lib; };
  software = {
    git = import ../software/git;
    gh = import ../software/gh;
    gitleaks = import ../software/gitleaks;
    lazygit = import ../software/lazygit;
  };
in
compose [
  software.git.versionControl
  software.lazygit.gitTui
  software.gh.githubCli
  software.gh.gitCredentialHelper
  software.gitleaks.secretScanner
]
