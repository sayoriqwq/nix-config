{ intentLib, lib }:

{
  fuzzySelector = intentLib.addModules {
    homeModules = [ ./capabilities/fuzzy-selector/home.nix ];
  };

  configure =
    {
      defaultCommand,
      previewCommand,
    }:
    intentLib.addModules {
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
