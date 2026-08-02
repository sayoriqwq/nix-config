{ pkgs, ... }:

{
  imports = [ ../common/cli/agent-python.nix ];

  home.packages = with pkgs; [
    graphviz
    (pkgs.callPackage ../../../packages/oh-my-pi { })
    poppler-utils
    rtk
  ];

  programs.git.ignores = [ "**/.claude/settings.local.json" ];
}
