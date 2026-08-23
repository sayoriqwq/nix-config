{ intentLib }:

{
  developmentCli = intentLib.addModules {
    homeModules = [ ./capabilities/development-cli/home.nix ];
  };
}
