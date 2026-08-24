{ lib }:

let
  intentLib = import ../lib.nix;
  software = {
    git = import ../../software/git { inherit intentLib; };
    gh = import ../../software/gh { inherit intentLib; };
    gitleaks = import ../../software/gitleaks { inherit intentLib; };
    lazygit = import ../../software/lazygit { inherit intentLib; };
  };
in
intentLib.realize (
  lib.pipe intentLib.empty [
    software.git.versionControl
    software.lazygit.gitTui
    software.gh.githubCli
    software.gh.gitCredentialHelper
    software.gitleaks.secretScanner
  ]
)
