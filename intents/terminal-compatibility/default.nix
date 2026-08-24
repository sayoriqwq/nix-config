{ lib }:

let
  intentLib = import ../lib.nix;
  software = {
    atuin = import ../../software/atuin { inherit intentLib; };
    direnv = import ../../software/direnv { inherit intentLib; };
    eza = import ../../software/eza { inherit intentLib; };
    fish = import ../../software/fish { inherit intentLib; };
    fzf = import ../../software/fzf { inherit intentLib lib; };
    lazygit = import ../../software/lazygit { inherit intentLib; };
    mise = import ../../software/mise { inherit intentLib; };
    orbstack = import ../../software/orbstack { inherit intentLib; };
    payRespects = import ../../software/pay-respects { inherit intentLib; };
    starship = import ../../software/starship { inherit intentLib; };
    wezterm = import ../../software/wezterm { inherit intentLib; };
    vscode = import ../../software/vscode { inherit intentLib; };
    yumeDesign = import ../../software/yume-design { inherit intentLib; };
    zed = import ../../software/zed { inherit intentLib; };
    zoxide = import ../../software/zoxide { inherit intentLib; };
    zsh = import ../../software/zsh { inherit intentLib; };
  };
in
intentLib.realize (
  lib.pipe intentLib.empty [
    software.fish.interactiveShell
    software.zsh.compatibilityShell
    software.yumeDesign.terminalTheme
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
)
