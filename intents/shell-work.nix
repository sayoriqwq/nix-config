{ lib }:

let
  compose = import ./lib.nix { inherit lib; };
  software = {
    atuin = import ../software/atuin;
    git = import ../software/git;
    payRespects = import ../software/pay-respects;
    bat = import ../software/bat;
    eza = import ../software/eza;
    fd = import ../software/fd;
    fish = import ../software/fish;
    fzf = import ../software/fzf { inherit lib; };
    jq = import ../software/jq;
    ripgrep = import ../software/ripgrep;
    starship = import ../software/starship;
    tmux = import ../software/tmux;
    tree = import ../software/tree;
    zoxide = import ../software/zoxide;
  };
in
compose [
  software.fish.interactiveShell
  software.git.versionControl
  software.atuin.shellHistory
  software.atuin.zshIntegration
  software.payRespects.commandCorrection
  software.payRespects.zshIntegration
  {
    homeModules = [
      ../software/nh/home-manager.nix
      ../software/btop/home-manager.nix
      ../software/fastfetch/home-manager.nix
      ../software/yazi/home-manager.nix
      ../software/helix/home-manager.nix
    ];
  }
  software.bat.contentViewer
  software.eza.directoryListing
  software.eza.zshIntegration
  software.fd.fileFinder
  software.fzf.fuzzySelector
  software.fzf.zshIntegration
  (software.fzf.configure {
    defaultCommand = "fd";
    previewCommand = "bat --color=always {}";
  })
  software.jq.jsonProcessor
  software.ripgrep.textSearch
  software.starship.shellPrompt
  software.starship.zshIntegration
  software.tmux.terminalMultiplexer
  software.tree.directoryTree
  software.zoxide.directoryJumper
  software.zoxide.zshIntegration
]
