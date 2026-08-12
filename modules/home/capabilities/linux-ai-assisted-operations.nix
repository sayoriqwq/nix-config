{
  config,
  inputs,
  pkgs,
  ...
}:

{
  imports = [
    ../common/cli/agent-python.nix
    ../common/state-paths.nix
  ];

  home.packages = [
    pkgs.codex
    inputs.ax.packages.${pkgs.stdenv.hostPlatform.system}.ax
    pkgs.rtk
  ];

  home.file.".codex/AGENTS.md" = {
    source = ../../../dotfiles/codex/AGENTS.linux.md;

    # The tracked policy is authoritative; do not allow a mutable installed
    # copy to diverge from the reviewed Nix generation.
    force = true;
  };

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.codex";
      owner = "Codex CLI";
      backup = "separate-policy";
      description = "Codex CLI authentication, session, history, plugins, skills, hooks, cache, databases, and mutable configuration remain writable and external. Only the stable global AGENTS.md policy is managed by Home Manager and linked into the Nix Store. RTK.md is generated, updated, and removed by the Nix-managed RTK CLI.";
    }
    {
      path = "${config.home.homeDirectory}/.cache/ax/fetch";
      owner = "ax";
      backup = "excluded";
      description = "Short-lived fetched-page cache owned by ax; upstream ax keeps this cache owner-only and expires entries after roughly two minutes. Home Manager only declares the boundary and never manages cache contents or credentials.";
    }
  ];
}
