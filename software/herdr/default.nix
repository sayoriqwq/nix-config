{ intentLib }:

{
  codingSession = intentLib.addModules {
    homeModules = [ ./capabilities/coding-session/home.nix ];
  };
}
