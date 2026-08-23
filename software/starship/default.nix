{ intentLib }:

{
  shellPrompt = intentLib.addModules {
    homeModules = [ ./capabilities/shell-prompt/home.nix ];
  };
}
