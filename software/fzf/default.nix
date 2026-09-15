{ lib }:

{
  fuzzySelector.homeModules = [ ./home-manager.nix ];

  zshIntegration.homeModules = [ ./zsh-integration.nix ];

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
