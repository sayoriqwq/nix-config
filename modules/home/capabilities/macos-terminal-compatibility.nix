{ config, ... }:

{
  imports = [
    ../common/state-paths.nix
    ../common/shell/zsh.nix
    ../common/cli/zoxide/zsh.nix
    ../darwin/hushlogin.nix
    ../desktop/terminal/adapters/wezterm.nix
  ];

  programs = {
    atuin.enableZshIntegration = true;
    direnv.enableZshIntegration = true;
    eza.enableZshIntegration = true;
    fzf.enableZshIntegration = true;
    lazygit.enableZshIntegration = true;
    mise.enableZshIntegration = true;
    pay-respects.enableZshIntegration = true;
    starship.enableZshIntegration = true;
  };

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.zhistory";
      owner = "Zsh";
      backup = "required";
      description = "Writable compatibility-shell history; Fish remains the primary shell.";
    }
  ];
}
