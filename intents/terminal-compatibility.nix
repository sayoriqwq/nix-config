{ lib }:

let
  compose = import ./lib.nix { inherit lib; };
  software = {
    atuin = import ../software/atuin;
    direnv = import ../software/direnv;
    eza = import ../software/eza;
    fish = import ../software/fish;
    fzf = import ../software/fzf { inherit lib; };
    lazygit = import ../software/lazygit;
    mise = import ../software/mise;
    orbstack = import ../software/orbstack;
    payRespects = import ../software/pay-respects;
    starship = import ../software/starship;
    wezterm = import ../software/wezterm;
    vscode = import ../software/vscode;
    zed = import ../software/zed;
    zoxide = import ../software/zoxide;
    zsh = import ../software/zsh;
  };
in
compose [
  software.fish.interactiveShell
  software.zsh.compatibilityShell
  software.wezterm.terminalEmulator
  software.orbstack.containerRuntime
  software.orbstack.shellIntegration
  software.vscode.editorCompatibility
  software.vscode.shellQuickCommand
  software.zed.guiEditor
  software.zed.zshQuickCommand
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
