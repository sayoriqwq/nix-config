{
  description = "sayori's declarative personal infrastructure";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager-darwin = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Issue #76: consume Herdr's stable Nix package through Home Manager.
    herdr.url = "github:herdrdev/herdr/v0.7.5";

    # Issue #90: consume only the reviewed source contract. Raycast's own
    # extension tooling remains in the leaf repository, so this is not a Flake.
    raycast-source = {
      url = "github:sayoriqwq/raycast/48f7a10551f7ae2cada8f7bbe4243ce36ed656ee";
      flake = false;
    };

    # Issue #155: consume the reviewed terminal design contract as data. The
    # runtime adapters remain owned by this repository, so this is not a Flake.
    yume-design = {
      url = "github:sayoriqwq/yume-design/047c1f44518ed353b8f5d821fc1f3f347ded9206";
      flake = false;
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

    # Issues #120 and #152: consume ax's published package output for the
    # explicitly approved workstation capabilities.
    # Keep ax's upstream Nixpkgs/bun2nix graph inside the leaf input.
    ax.url = "github:yusukebe/ax";

    # Issue #157: pin the reviewed Nixpkgs leaf that contains the 2.5.2
    # Clash Verge Rev package expression. It is called with the Linux release
    # package set below; this source is not imported as another package set.
    clash-verge-rev-package-source = {
      url = "github:NixOS/nixpkgs/d9e5fe493950fb219c0e7ccd2c0430a3babd77a6";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      home-manager,
      home-manager-darwin,
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
      clashVergeRevPkgs = packagesFor "x86_64-linux";
      clashVergeRevPackage = import ./packages/clash-verge-rev {
        pkgs = clashVergeRevPkgs;
        source = inputs.clash-verge-rev-package-source;
      };
      zedNightlyFor = system: (packagesFor system).callPackage ./software/zed/package.nix { };
      zedNightlyUpdaterFor =
        system:
        let
          pkgs = packagesFor system;
        in
        pkgs.writeShellApplication {
          name = "sync-zed-nightly";
          runtimeInputs = [
            pkgs.curl
            pkgs.git
            pkgs.jq
            pkgs.nix
            pkgs.python3
          ];
          text = builtins.readFile ./software/zed/update.sh;
        };
      serverModules = [
        ./hosts/server
        ./modules/nixos/base.nix
        ./modules/nixos/server.nix
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
      ];
      serverRecoveryPkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
      serverRecoveryNetworkTest = serverRecoveryOperation.networkTest;
      serverRecoveryPolicyCheck = import ./checks/server-recovery/policy.nix {
        installConfiguration = serverRecoveryOperation.installConfiguration;
        pkgs = serverRecoveryPkgs;
        productionConfiguration = self.nixosConfigurations.server;
        runner = serverRecoveryOperation.runner;
        inherit username;
      };
      nixosAnywherePackage = nixos-anywhere.packages.x86_64-linux.nixos-anywhere;
      serverRecoveryOperation = import ./operations/server-recovery {
        inherit
          inputs
          nixosAnywherePackage
          self
          serverModules
          username
          ;
        pkgs = serverRecoveryPkgs;
      };
      darwinPkgs = packagesFor "aarch64-darwin";
      intentLib = import ./intents/lib.nix;
      fzfConfigureCheck = import ./checks/terminal-work/fzf-configure.nix {
        homeManager = home-manager-darwin;
        inherit intentLib;
        inherit (darwinPkgs) lib;
        pkgs = darwinPkgs;
      };
      zedAddTaskCheck = import ./checks/code-development/zed-add-task.nix {
        homeManager = home-manager-darwin;
        inherit intentLib;
        inherit (darwinPkgs) lib;
        pkgs = darwinPkgs;
      };
      macbookPinshiftDevelopmentCheck =
        import ./checks/code-development/macbook-pinshift-development.nix
          {
            inherit (darwinPkgs) lib;
            inherit username;
            macbookConfiguration = self.darwinConfigurations.macbook;
            nixboxConfiguration = self.nixosConfigurations.nixbox;
            pkgs = darwinPkgs;
            serverConfiguration = self.nixosConfigurations.server;
          };
      tailscaleSshProxyCheck = import ./checks/stable-workstation-access/tailscale-ssh-proxy.nix {
        homeManager = home-manager-darwin;
        inherit (darwinPkgs) lib;
        pkgs = darwinPkgs;
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
          home-manager-darwin.darwinModules.home-manager
        ];
      };

      nixosConfigurations.nixbox = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit
            clashVergeRevPackage
            inputs
            self
            username
            ;
        };
        modules = [
          ./hosts/nixbox
          ./modules/nixos/base.nix
          home-manager.nixosModules.home-manager
        ];
      };

      nixosConfigurations.server = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs self username;
        };
        modules = serverModules;
      };

      nixosConfigurations.server-recovery-install = serverRecoveryOperation.installConfiguration;

      # Explicit package outputs give CI and future hosts stable validation
      # targets for the narrow Clash seam and Zed's owner-local binary package.
      packages = {
        aarch64-darwin = {
          sync-zed-nightly = zedNightlyUpdaterFor "aarch64-darwin";
          zed-nightly = zedNightlyFor "aarch64-darwin";
        };
        x86_64-linux = {
          clash-verge-rev = clashVergeRevPackage;
          server-recovery-test = serverRecoveryOperation.runner;
          sync-zed-nightly = zedNightlyUpdaterFor "x86_64-linux";
          zed-nightly = zedNightlyFor "x86_64-linux";
        };
      };

      apps = {
        aarch64-darwin.sync-zed-nightly = {
          type = "app";
          program = "${zedNightlyUpdaterFor "aarch64-darwin"}/bin/sync-zed-nightly";
        };
        x86_64-linux = {
          server-recovery-test = {
            type = "app";
            program = "${serverRecoveryOperation.runner}/bin/server-recovery-test";
          };
          sync-zed-nightly = {
            type = "app";
            program = "${zedNightlyUpdaterFor "x86_64-linux"}/bin/sync-zed-nightly";
          };
        };
      };

      checks = {
        aarch64-darwin = {
          fzf-configure = fzfConfigureCheck;
          macbook-pinshift-development = macbookPinshiftDevelopmentCheck;
          macbook-system = self.darwinConfigurations.macbook.system;
          tailscale-ssh-proxy = tailscaleSshProxyCheck;
          zed-add-task = zedAddTaskCheck;
        };
        x86_64-linux = {
          nixbox-system = self.nixosConfigurations.nixbox.config.system.build.toplevel;
          server-system = self.nixosConfigurations.server.config.system.build.toplevel;
          server-recovery-network = serverRecoveryNetworkTest;
          server-recovery-policy = serverRecoveryPolicyCheck;
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
