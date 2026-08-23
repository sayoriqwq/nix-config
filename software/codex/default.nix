{ intentLib }:

{
  codingAgent = intentLib.addModules {
    homeModules = [ ./capabilities/coding-agent/home.nix ];
  };
}
