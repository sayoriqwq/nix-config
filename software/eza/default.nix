{ intentLib }:

{
  directoryListing = intentLib.addModules {
    homeModules = [ ./capabilities/directory-listing/home.nix ];
  };

  zshIntegration = intentLib.addModules {
    homeModules = [ ./capabilities/directory-listing/zsh.nix ];
  };
}
