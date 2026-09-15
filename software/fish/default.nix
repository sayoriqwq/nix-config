{
  interactiveShell = {
    darwinModules = [ ./darwin.nix ];
    nixosModules = [ ./nixos.nix ];
    homeModules = [ ./home-manager.nix ];
  };
}
