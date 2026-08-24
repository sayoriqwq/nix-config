{ intentLib }:

{
  desktopAudio = intentLib.addModules {
    nixosModules = [ ./capabilities/desktop-audio/nixos.nix ];
  };
}
