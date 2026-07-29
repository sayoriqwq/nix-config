{ config, pkgs, ... }:

{
  imports = [
    ../common/state-paths.nix
    ../common/cli/gh.nix
    ../common/cli/git-github.nix
    ../common/cli/lazygit
  ];

  home.packages = [ pkgs.gitleaks ];

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.config/gh/hosts.yml";
      owner = "GitHub CLI";
      backup = "separate-policy";
      description = "GitHub authentication state; never managed by Nix or committed.";
    }
  ];
}
