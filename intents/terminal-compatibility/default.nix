{ lib }:

let
  intentLib = import ../lib.nix;
  software = {
    atuin = import ../../software/atuin { inherit intentLib; };
    direnv = import ../../software/direnv { inherit intentLib; };
    eza = import ../../software/eza { inherit intentLib; };
    fzf = import ../../software/fzf { inherit intentLib lib; };
    lazygit = import ../../software/lazygit { inherit intentLib; };
    mise = import ../../software/mise { inherit intentLib; };
    payRespects = import ../../software/pay-respects { inherit intentLib; };
    starship = import ../../software/starship { inherit intentLib; };
    wezterm = import ../../software/wezterm { inherit intentLib; };
    zoxide = import ../../software/zoxide { inherit intentLib; };
    zsh = import ../../software/zsh { inherit intentLib; };
  };
in
intentLib.realize (
  lib.pipe intentLib.empty [
    software.zsh.compatibilityShell
    software.wezterm.terminalEmulator
    software.atuin.shellHistory
    software.atuin.zshIntegration
    software.direnv.developmentEnvironment
    software.direnv.zshIntegration
    software.eza.directoryListing
    software.eza.zshIntegration
    software.fzf.fuzzySelector
    software.fzf.zshIntegration
    software.lazygit.gitTui
    software.lazygit.zshIntegration
    software.mise.runtimeManager
    software.mise.zshIntegration
    software.payRespects.commandCorrection
    software.payRespects.zshIntegration
    software.starship.shellPrompt
    software.starship.zshIntegration
    software.zoxide.directoryJumper
    software.zoxide.zshIntegration
  ]
)
