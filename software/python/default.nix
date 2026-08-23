{ intentLib }:

{
  agentInterpreter = intentLib.addModules {
    homeModules = [ ./capabilities/agent-interpreter/home.nix ];
  };
}
