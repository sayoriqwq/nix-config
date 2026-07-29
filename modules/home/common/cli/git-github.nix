{ pkgs, ... }:

{
  # Authentication state remains in gh's private hosts file. This primitive
  # owns only the GitHub-specific credential-helper wiring.
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
}
