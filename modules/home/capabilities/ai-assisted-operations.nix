{ config, pkgs, ... }:

{
  imports = [
    ../common/cli/agent-python.nix
    ../common/cli/codex-agent-policy.nix
    ../common/state-paths.nix
  ];

  home.packages = with pkgs; [
    graphviz
    (pkgs.callPackage ../../../packages/codex-cli { })
    claude-code
    (pkgs.callPackage ../../../packages/antigravity-cli { })
    (pkgs.callPackage ../../../packages/oh-my-pi { })
    poppler-utils
    rtk
  ];

  programs.git.ignores = [ "**/.claude/settings.local.json" ];

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.codex";
      owner = "Codex CLI";
      backup = "separate-policy";
      description = "Codex CLI authentication, session, history, plugins, hooks, cache, databases, and mutable configuration remain writable and external. Only the stable global AGENTS.md policy is managed by Home Manager and linked into the Nix Store.";
    }
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
    {
      path = "${config.home.homeDirectory}/.gemini";
      owner = "Antigravity CLI";
      backup = "separate-policy";
      description = "Antigravity CLI authentication, configuration, session, history, plugins, hooks, and cache contents remain writable and external and are never linked into the Nix Store.";
    }
    {
      path = "${config.home.homeDirectory}/.omp";
      owner = "Oh My Pi";
      backup = "separate-policy";
      description = "Oh My Pi authentication, configuration, session, history, plugins, hooks, and cache contents remain writable and external and are never linked into the Nix Store.";
    }
  ];
}
