{ intentLib }:

{
  interactiveShell = intentLib.addModules {
    darwinModules = [ ./capabilities/interactive-shell/darwin.nix ];
    nixosModules = [ ./capabilities/interactive-shell/nixos.nix ];
    homeModules = [ ./capabilities/interactive-shell/home.nix ];
  };
}
