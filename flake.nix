{
  description = "sayori's declarative personal infrastructure";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko/ff8702b4de27f72b4c78573dfb89ec74e36abdf1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ADR-0006: consume only the upstream Nightly package output. Zed keeps
    # its own pinned Nixpkgs/Rust/Crane graph inside this leaf input.
    zed.url = "github:zed-industries/zed";
  };

  outputs =
    inputs@{
      self,
      home-manager,
      nix-darwin,
      nixpkgs,
      nixpkgs-darwin,
      disko,
      ...
    }:
    let
      packagesFor =
        system:
        import (if system == "aarch64-darwin" then nixpkgs-darwin else nixpkgs) {
          inherit system;
        };
    in
    {
      darwinConfigurations.macbook = nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit inputs self;
          username = "sayori";
        };
        modules = [
          ./hosts/macbook
          ./modules/darwin/base.nix
          home-manager.darwinModules.home-manager
        ];
      };

      nixosConfigurations.nixbox = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs self;
          username = "sayori";
        };
        modules = [
          ./hosts/nixbox
          ./modules/nixos/base.nix
          ./modules/nixos/desktop.nix
          home-manager.nixosModules.home-manager
        ];
      };

      nixosConfigurations.server = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs self;
          username = "sayori";
        };
        modules = [
          ./hosts/server
          ./modules/nixos/base.nix
          ./modules/nixos/server.nix
          disko.nixosModules.disko
          home-manager.nixosModules.home-manager
        ];
      };

      # Explicit package outputs give CI and future hosts a stable validation
      # target without importing Zed's internal Flake modules.
      packages = {
        aarch64-darwin.zed-nightly = inputs.zed.packages.aarch64-darwin.default;
        x86_64-linux.zed-nightly = inputs.zed.packages.x86_64-linux.default;
      };

      formatter = {
        aarch64-darwin = (packagesFor "aarch64-darwin").nixfmt;
        # Used by the temporary Linux validation container on Apple Silicon.
        aarch64-linux = (packagesFor "aarch64-linux").nixfmt;
        x86_64-linux = (packagesFor "x86_64-linux").nixfmt;
      };
    };
}
