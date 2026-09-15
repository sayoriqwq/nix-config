{ lib }:

let
  compose = import ./lib.nix { inherit lib; };
  software = {
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
  software.bat.contentViewer
  software.eza.directoryListing
  software.fd.fileFinder
  software.fzf.fuzzySelector
  (software.fzf.configure {
    defaultCommand = "fd";
    previewCommand = "bat --color=always {}";
  })
  software.jq.jsonProcessor
  software.ripgrep.textSearch
  software.starship.shellPrompt
  software.tmux.terminalMultiplexer
  software.tree.directoryTree
  software.zoxide.directoryJumper
]
