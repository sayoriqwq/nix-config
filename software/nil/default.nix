{ intentLib }:

{
  nixLanguageServer = intentLib.addModules {
    homeModules = [ ./capabilities/nix-language-server/home.nix ];
  };
}
