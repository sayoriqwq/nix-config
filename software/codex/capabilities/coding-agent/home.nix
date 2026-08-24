{ pkgs, ... }:

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
in
{
  home.packages = [ codexPackage ];

  home.file.".codex/AGENTS.md" = {
    source = policySource;
    force = true;
  };

}
