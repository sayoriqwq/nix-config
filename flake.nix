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

    # Issue #76: consume Herdr's stable Nix package through Home Manager.
    herdr.url = "github:herdrdev/herdr/v0.7.5";

    disko = {
      url = "github:nix-community/disko/ff8702b4de27f72b4c78573dfb89ec74e36abdf1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere/5887f1c72fbf0e88000716237194de414d2299ee";
      inputs.disko.follows = "disko";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixos-stable.follows = "nixpkgs";
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
      nixos-anywhere,
      ...
    }:
    let
      username = "sayori";
      packagesFor =
        system:
        import (if system == "aarch64-darwin" then nixpkgs-darwin else nixpkgs) {
          inherit system;
        };
      serverModules = [
        ./hosts/server
        ./modules/nixos/base.nix
        ./modules/nixos/server.nix
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        ./tests/phase-9/install-test.nix
      ];
      phase9Pkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
      phase9Preflight = import ./tests/phase-9/preflight.nix { pkgs = phase9Pkgs; };
      phase9NetworkTest = import ./tests/phase-9/network-test.nix {
        inherit
          inputs
          phase9Preflight
          serverModules
          username
          ;
        pkgs = phase9Pkgs;
      };
      phase9PolicyCheck = import ./tests/phase-9/policy-check.nix {
        inherit phase9Pkgs username;
        serverConfiguration = self.nixosConfigurations.server;
      };
      nixosAnywherePackage = nixos-anywhere.packages.x86_64-linux.nixos-anywhere;
      phase9TestRunner = import ./tests/phase-9/runner.nix {
        inherit nixosAnywherePackage;
        pkgs = phase9Pkgs;
      };
    in
    {
      darwinConfigurations.macbook = nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit inputs self username;
        };
        modules = [
          ./hosts/macbook
          ./modules/darwin/base.nix
          home-manager.darwinModules.home-manager
        ];
      };

      nixosConfigurations.nixbox = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs self username;
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
          inherit inputs self username;
        };
        modules = serverModules;
      };

      # Explicit package outputs give CI and future hosts a stable validation
      # target without importing Zed's internal Flake modules.
      packages = {
        aarch64-darwin.zed-nightly = inputs.zed.packages.aarch64-darwin.default;
        x86_64-linux = {
          inherit phase9Preflight;
          nixos-anywhere = nixosAnywherePackage;
          phase9-test = phase9TestRunner;
          zed-nightly = inputs.zed.packages.x86_64-linux.default;
        };
      };

      apps.x86_64-linux = {
        nixos-anywhere = {
          type = "app";
          program = "${nixosAnywherePackage}/bin/nixos-anywhere";
        };
        phase9-test = {
          type = "app";
          program = "${phase9TestRunner}/bin/phase9-test";
        };
      };

      checks = {
        aarch64-darwin.macbook-zsh-zoxide = import ./tests/macos/zsh-zoxide.nix {
          pkgs = packagesFor "aarch64-darwin";
          zshrc =
            self.darwinConfigurations.macbook.config.home-manager.users.${username}.home.file."./.zshrc".source;
        };
        x86_64-linux = {
          phase9-network = phase9NetworkTest;
          phase9-policy = phase9PolicyCheck;
        };
      };

      formatter = {
        aarch64-darwin = (packagesFor "aarch64-darwin").nixfmt;
        # Used by the temporary Linux validation container on Apple Silicon.
        aarch64-linux = (packagesFor "aarch64-linux").nixfmt;
        x86_64-linux = (packagesFor "x86_64-linux").nixfmt;
      };
    };
}
