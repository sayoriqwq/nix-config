{ lib }:

let
  intentLib = import ../lib.nix;
  software = {
    bat = import ../../software/bat { inherit intentLib; };
    eza = import ../../software/eza { inherit intentLib; };
    fd = import ../../software/fd { inherit intentLib; };
    fish = import ../../software/fish { inherit intentLib; };
    fzf = import ../../software/fzf { inherit intentLib lib; };
    jq = import ../../software/jq { inherit intentLib; };
    ripgrep = import ../../software/ripgrep { inherit intentLib; };
    starship = import ../../software/starship { inherit intentLib; };
    tmux = import ../../software/tmux { inherit intentLib; };
    tree = import ../../software/tree { inherit intentLib; };
    yumeDesign = import ../../software/yume-design { inherit intentLib; };
    zoxide = import ../../software/zoxide { inherit intentLib; };
  };
in
intentLib.realize (
  lib.pipe intentLib.empty [
    software.yumeDesign.terminalTheme
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
)
