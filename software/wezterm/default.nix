{ intentLib }:

{
  terminalEmulator = intentLib.addModules {
    homeModules = [ ./capabilities/terminal-emulator/home.nix ];
  };
}
