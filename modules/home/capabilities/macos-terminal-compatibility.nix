{ config, ... }:

{
  imports = [
    ../common/state-paths.nix
    ../common/shell/zsh.nix
    ../common/cli/atuin-zsh.nix
    ../common/cli/direnv-zsh.nix
    ../common/cli/eza-zsh.nix
    ../common/cli/fzf/zsh.nix
    ../common/cli/lazygit/zsh.nix
    ../common/cli/mise-zsh.nix
    ../common/cli/pay-respects-zsh.nix
    ../common/cli/starship-zsh.nix
    ../common/cli/zoxide/zsh.nix
    ../darwin/hushlogin.nix
    ../desktop/terminal/adapters/wezterm.nix
  ];

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.zhistory";
      owner = "Zsh";
      backup = "required";
      description = "Writable compatibility-shell history; Fish remains the primary shell.";
    }
  ];
}
