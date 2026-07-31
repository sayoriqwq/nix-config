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
      phase10NixboxBootstrapTest = import ./tests/phase-10/nixbox-bootstrap-test.nix {
        inherit username;
        pkgs = phase9Pkgs;
        serverConfiguration = self.nixosConfigurations.server;
      };
      nixosAnywherePackage = nixos-anywhere.packages.x86_64-linux.nixos-anywhere;
      phase9TestRunner = import ./tests/phase-9/runner.nix {
        inherit nixosAnywherePackage;
        pkgs = phase9Pkgs;
      };
      phase10Pkgs = packagesFor "aarch64-darwin";
      phase10Preflight = import ./tools/phase-10/preflight.nix {
        pkgs = phase10Pkgs;
        serverConfiguration = self.nixosConfigurations.server;
      };
      phase10NixboxBootstrap = import ./tools/phase-10/nixbox-bootstrap.nix {
        inherit phase10Preflight username;
        pkgs = phase10Pkgs;
        serverConfiguration = self.nixosConfigurations.server;
      };
      phase10RemotePreflightCheck =
        phase10Pkgs.runCommand "phase10-remote-preflight-shellcheck"
          {
            nativeBuildInputs = [ phase10Pkgs.shellcheck ];
          }
          ''
            shellcheck ${./tools/phase-10/remote-preflight.sh}
            touch "$out"
          '';
      phase10RemoteNixboxBootstrapCheck =
        phase10Pkgs.runCommand "phase10-remote-nixbox-bootstrap-shellcheck"
          {
            nativeBuildInputs = [ phase10Pkgs.shellcheck ];
          }
          ''
            shellcheck ${./tools/phase-10/remote-nixbox-bootstrap.sh}
            touch "$out"
          '';
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
        aarch64-darwin = {
          phase10-bootstrap-nixbox = phase10NixboxBootstrap.add;
          phase10-preflight = phase10Preflight;
          phase10-rollback-nixbox-bootstrap = phase10NixboxBootstrap.remove;
          zed-nightly = inputs.zed.packages.aarch64-darwin.default;
        };
        x86_64-linux = {
          inherit phase9Preflight;
          nixos-anywhere = nixosAnywherePackage;
          phase9-test = phase9TestRunner;
          zed-nightly = inputs.zed.packages.x86_64-linux.default;
        };
      };

      apps.aarch64-darwin = {
        phase10-bootstrap-nixbox = {
          type = "app";
          program = "${phase10NixboxBootstrap.add}/bin/phase10-bootstrap-nixbox";
        };
        phase10-preflight = {
          type = "app";
          program = "${phase10Preflight}/bin/phase10-preflight";
        };
        phase10-rollback-nixbox-bootstrap = {
          type = "app";
          program = "${phase10NixboxBootstrap.remove}/bin/phase10-rollback-nixbox-bootstrap";
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

      checks.aarch64-darwin = {
        phase10-bootstrap-nixbox = phase10NixboxBootstrap.add;
        phase10-preflight = phase10Preflight;
        phase10-remote-nixbox-bootstrap-shellcheck = phase10RemoteNixboxBootstrapCheck;
        phase10-remote-preflight-shellcheck = phase10RemotePreflightCheck;
        phase10-rollback-nixbox-bootstrap = phase10NixboxBootstrap.remove;
      };

      checks.x86_64-linux = {
        phase9-network = phase9NetworkTest;
        phase9-policy = phase9PolicyCheck;
        phase10-nixbox-bootstrap = phase10NixboxBootstrapTest;
      };

      formatter = {
        aarch64-darwin = (packagesFor "aarch64-darwin").nixfmt;
        # Used by the temporary Linux validation container on Apple Silicon.
        aarch64-linux = (packagesFor "aarch64-linux").nixfmt;
        x86_64-linux = (packagesFor "x86_64-linux").nixfmt;
      };
    };
}
