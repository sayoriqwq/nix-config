{ intentLib }:

{
  jsonProcessor = intentLib.addModules {
    homeModules = [ ./capabilities/json-processor/home.nix ];
  };
}
