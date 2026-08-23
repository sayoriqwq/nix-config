{ intentLib }:

{
  textSearch = intentLib.addModules {
    homeModules = [ ./capabilities/text-search/home.nix ];
  };
}
