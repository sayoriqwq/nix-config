{ pkgs, ... }:

{
  home.packages = [ pkgs.claude-code ];

  programs.git.ignores = [ "**/.claude/settings.local.json" ];
}
