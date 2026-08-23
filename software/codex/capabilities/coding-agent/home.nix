{ config, pkgs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  codexPackage =
    if system == "aarch64-darwin" then
      pkgs.callPackage ../../package.nix { }
    else if system == "x86_64-linux" then
      pkgs.codex
    else
      throw "Codex coding-agent capability is unsupported on ${system}";
  policySource =
    if system == "aarch64-darwin" then
      ../../../../dotfiles/codex/AGENTS.md
    else
      ../../../../dotfiles/codex/AGENTS.linux.md;
  stateDescription =
    if system == "aarch64-darwin" then
      "Codex CLI authentication, session, history, plugins, hooks, cache, databases, and mutable configuration remain writable and external. Only the stable global AGENTS.md policy is managed by Home Manager and linked into the Nix Store. RTK.md is generated, updated, and removed by the Nix-managed RTK CLI."
    else
      "Codex CLI authentication, session, history, plugins, skills, hooks, cache, databases, and mutable configuration remain writable and external. Only the stable global AGENTS.md policy is managed by Home Manager and linked into the Nix Store. RTK.md is generated, updated, and removed by the Nix-managed RTK CLI.";
in
{
  imports = [ ../../../../modules/home/common/state-paths.nix ];

  home.packages = [ codexPackage ];

  home.file.".codex/AGENTS.md" = {
    source = policySource;
    force = true;
  };

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.codex";
      owner = "Codex CLI";
      backup = "separate-policy";
      description = stateDescription;
    }
  ];
}
