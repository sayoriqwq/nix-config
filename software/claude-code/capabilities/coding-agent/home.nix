{ config, pkgs, ... }:

{
  imports = [ ../../../../modules/home/common/state-paths.nix ];

  home.packages = [ pkgs.claude-code ];

  programs.git.ignores = [ "**/.claude/settings.local.json" ];

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.claude";
      owner = "Claude Code";
      backup = "separate-policy";
      description = "Claude Code authentication, configuration, session, history, plugins, hooks, and cache contents remain writable and external and are never linked into the Nix Store.";
    }
    {
      path = "${config.home.homeDirectory}/.claude.json";
      owner = "Claude Code";
      backup = "separate-policy";
      description = "Claude Code authentication, configuration, session, history, plugins, hooks, and cache contents remain writable and external and are never linked into the Nix Store.";
    }
  ];
}
