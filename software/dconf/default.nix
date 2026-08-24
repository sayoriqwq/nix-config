{ intentLib }:

{
  userSettings = intentLib.addModules {
    homeModules = [ ./capabilities/user-settings/home.nix ];
  };
}
