{ intentLib }:

{
  directoryListing = intentLib.addModules {
    homeModules = [ ./capabilities/directory-listing/home.nix ];
  };
}
