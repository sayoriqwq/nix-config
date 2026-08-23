{ config, pkgs, ... }:

{
  imports = [
    ../common/state-paths.nix
    ../common/cli/gh.nix
  ];

  home.packages = [ pkgs.gitleaks ];

  # Authentication state remains in gh's private hosts file. This module owns
  # only the GitHub-specific credential-helper wiring, not Git foundation.
  programs.git.settings.credential = {
    "https://github.com".helper = [
      ""
      "${pkgs.gh}/bin/gh auth git-credential"
    ];
    "https://gist.github.com".helper = [
      ""
      "${pkgs.gh}/bin/gh auth git-credential"
    ];
  };

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.config/gh/hosts.yml";
      owner = "GitHub CLI";
      backup = "separate-policy";
      description = "GitHub authentication state; never managed by Nix or committed.";
    }
  ];
}
