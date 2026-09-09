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
in
{
  # Personal instructions and config stay writable and owned by the user/Codex.
  home.packages = [ codexPackage ];
}
