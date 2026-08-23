{ config, lib, ... }:

{
  imports = [ ../../../../modules/home/common/state-paths.nix ];

  programs.fish.interactiveShellInit = lib.mkAfter ''
    test -f "$HOME/.orbstack/shell/init2.fish"; and source "$HOME/.orbstack/shell/init2.fish"
  '';

  programs.zsh.profileExtra = ''
    [[ -f "$HOME/.orbstack/shell/init.zsh" ]] && source "$HOME/.orbstack/shell/init.zsh"
  '';

  programs.man.generateCaches = false;

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.orbstack";
      owner = "OrbStack";
      backup = "separate-policy";
      description = "Container runtime integration, VM, image, container and volume state remain outside Nix ownership.";
    }
  ];
}
