{ intentLib }:

{
  authenticationAgent = intentLib.addModules {
    homeModules = [ ./capabilities/authentication-agent/home.nix ];
  };
}
