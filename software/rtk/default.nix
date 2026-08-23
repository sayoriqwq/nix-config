{ intentLib }:

{
  outputCompression = intentLib.addModules {
    homeModules = [ ./capabilities/output-compression/home.nix ];
  };
}
