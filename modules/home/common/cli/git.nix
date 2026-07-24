{ pkgs, ... }:

{
  programs.git = {
    enable = true;
    includes = [ { path = "~/.config/git/identity.inc"; } ];
    ignores = [ "**/.claude/settings.local.json" ];

    # Authentication state remains in gh's private hosts file. Git only owns
    # the credential-helper wiring.
    settings.credential = {
      "https://github.com".helper = [
        ""
        "${pkgs.gh}/bin/gh auth git-credential"
      ];
      "https://gist.github.com".helper = [
        ""
        "${pkgs.gh}/bin/gh auth git-credential"
      ];
    };
  };
}
