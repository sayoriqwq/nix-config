{ intentLib }:

{
  directoryJumper = intentLib.addModules {
    homeModules = [ ./capabilities/directory-jumper/home.nix ];
  };
}
