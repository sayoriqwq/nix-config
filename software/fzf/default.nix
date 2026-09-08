{ lib }:

{
  fuzzySelector.homeModules = [ ./capabilities/fuzzy-selector/home.nix ];

  zshIntegration.homeModules = [ ./capabilities/fuzzy-selector/zsh.nix ];

  configure =
    {
      defaultCommand,
      previewCommand,
    }:
    {
      homeModules = [
        {
          programs.fzf = {
            inherit defaultCommand;
            defaultOptions = [ "--preview ${lib.escapeShellArg previewCommand}" ];
          };
        }
      ];
    };
}
