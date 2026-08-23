{ config, ... }:

{
  imports = [
    ../../../software/yume-design/capabilities/terminal-theme/home.nix
    ../common/state-paths.nix
    ../common/shell/zsh.nix
    ../../../software/zoxide/capabilities/directory-jumper/zsh.nix
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
    zoxide.enableZshIntegration = true;
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
