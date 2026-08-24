{ lib }:

let
  intentLib = import ../lib.nix;
  software = {
    gh = import ../../software/gh { inherit intentLib; };
    gitleaks = import ../../software/gitleaks { inherit intentLib; };
  };
in
intentLib.realize (
  lib.pipe intentLib.empty [
    software.gh.githubCli
    software.gh.gitCredentialHelper
    software.gitleaks.secretScanner
  ]
)
