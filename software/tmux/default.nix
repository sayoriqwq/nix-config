{ intentLib }:

{
  terminalMultiplexer = intentLib.addModules {
    homeModules = [ ./capabilities/terminal-multiplexer/home.nix ];
  };
}
