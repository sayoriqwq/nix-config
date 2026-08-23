{
  imports = [ ../../software/zoxide/capabilities/directory-jumper/zsh.nix ];

  # This module makes the existing cross-software compatibility relationship
  # explicit at the Intent layer. The frozen Wave 3 sibling owners do not yet
  # expose Zsh integration contributions; a follow-up can replace each option
  # with its owner-local contribution without changing the user result.
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
}
