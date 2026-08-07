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
      serverModules = [
        ./hosts/server
        ./modules/nixos/base.nix
        ./modules/nixos/server.nix
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        ./tests/server-recovery/install-test.nix
      ];
      serverRecoveryPkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
      serverRecoveryPreflight = import ./tests/server-recovery/preflight.nix {
        pkgs = serverRecoveryPkgs;
      };
      serverRecoveryNetworkTest = import ./tests/server-recovery/network-test.nix {
        inherit
          inputs
          serverModules
          serverRecoveryPreflight
          username
          ;
        pkgs = serverRecoveryPkgs;
      };
      serverRecoveryPolicyCheck = import ./tests/server-recovery/policy-check.nix {
        inherit username;
        pkgs = serverRecoveryPkgs;
        serverConfiguration = self.nixosConfigurations.server;
      };
      nixosAnywherePackage = nixos-anywhere.packages.x86_64-linux.nixos-anywhere;
      serverRecoveryTestRunner = import ./tests/server-recovery/runner.nix {
        inherit nixosAnywherePackage;
        pkgs = serverRecoveryPkgs;
      };
      darwinPkgs = packagesFor "aarch64-darwin";
      phase11SopsPolicy = import ./tests/phase-11/policy-check.nix {
        adminRecipient = "age1lece5fgs54jycjjhclgtwvugrxuzajacd0mdsxna8v3sunj9tdsqfwdyyn";
        hostRecipients = {
          macbook = "age1a49p4p9k0xwkwkh9e0t3zw88hwsuafs4t37nvfw3vtcq3kux0f0qavyd8r";
          nixbox = "age1xnjsz6n9uzsmj3w5umdwv9scltt035rc8wne0u2hsh2zuafcdu2qhu5knn";
          server = "age1zsv4uz44lkr0emz6u49jtwgg3svevm02e5xwgcp9fqwtw56vfv8qf60g8c";
        };
        macbookConfiguration = self.darwinConfigurations.macbook;
        nixboxConfiguration = self.nixosConfigurations.nixbox;
        pkgs = darwinPkgs;
        serverConfiguration = self.nixosConfigurations.server;
        source = ./.;
      };
      zedNixLspPolicy = import ./tests/zed-editor/nix-lsp-policy.nix {
        macbookConfiguration = self.darwinConfigurations.macbook;
        nixboxConfiguration = self.nixosConfigurations.nixbox;
        pkgs = darwinPkgs;
        serverConfiguration = self.nixosConfigurations.server;
      };
      macosRollingInputsPolicy = import ./tests/macos/rolling-inputs.nix {
        macbookConfiguration = self.darwinConfigurations.macbook;
        nixboxConfiguration = self.nixosConfigurations.nixbox;
        pkgs = darwinPkgs;
        serverConfiguration = self.nixosConfigurations.server;
        source = ./.;
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
          zed-nightly = inputs.zed.packages.aarch64-darwin.default;
        };
        x86_64-linux = {
          server-recovery-test = serverRecoveryTestRunner;
          zed-nightly = inputs.zed.packages.x86_64-linux.default;
        };
      };

      apps.x86_64-linux = {
        server-recovery-test = {
          type = "app";
          program = "${serverRecoveryTestRunner}/bin/server-recovery-test";
        };
      };

      checks = {
        aarch64-darwin = {
          sops-age-policy = phase11SopsPolicy;
          zed-nix-lsp-policy = zedNixLspPolicy;
          macos-rolling-inputs = macosRollingInputsPolicy;
          macbook-codex-agent-policy = import ./tests/macos/codex-agent-policy.nix {
            homeConfiguration = self.darwinConfigurations.macbook.config.home-manager.users.${username};
            pkgs = self.darwinConfigurations.macbook.pkgs;
          };
          macbook-rtk-integration = import ./tests/macos/rtk-integration.nix {
            homeConfiguration = self.darwinConfigurations.macbook.config.home-manager.users.${username};
            pkgs = self.darwinConfigurations.macbook.pkgs;
            profilePackages =
              self.darwinConfigurations.macbook.config.home-manager.users.${username}.home.packages;
          };
          macbook-agent-python = import ./tests/macos/agent-python.nix {
            pkgs = self.darwinConfigurations.macbook.pkgs;
            profilePackages =
              self.darwinConfigurations.macbook.config.home-manager.users.${username}.home.packages;
          };
          macbook-postgresql-retirement = import ./tests/macos/postgresql-retirement.nix {
            homeConfiguration = self.darwinConfigurations.macbook.config.home-manager.users.${username};
            pkgs = self.darwinConfigurations.macbook.pkgs;
          };
          macbook-ai-clients = import ./tests/macos/ai-clients.nix {
            pkgs = self.darwinConfigurations.macbook.pkgs;
            profilePackages =
              self.darwinConfigurations.macbook.config.home-manager.users.${username}.home.packages;
          };
          macbook-zsh-zoxide = import ./tests/macos/zsh-zoxide.nix {
            pkgs = packagesFor "aarch64-darwin";
            zshrc =
              self.darwinConfigurations.macbook.config.home-manager.users.${username}.home.file."./.zshrc".source;
          };
          editor-capability-launchers = import ./tests/macos/editor-launchers.nix {
            lib = darwinPkgs.lib;
            macbookConfiguration = self.darwinConfigurations.macbook;
            nixboxConfiguration = self.nixosConfigurations.nixbox;
            pkgs = darwinPkgs;
            serverConfiguration = self.nixosConfigurations.server;
          };
          macbook-raycast-source = import ./tests/macos/raycast-source.nix {
            inherit (self.darwinConfigurations.macbook.pkgs) lib;
            casks = self.darwinConfigurations.macbook.config.homebrew.casks;
            pkgs = self.darwinConfigurations.macbook.pkgs;
            scriptCommands =
              self.darwinConfigurations.macbook.config.home-manager.users.${username}.xdg.dataFile."raycast/script-commands".source;
          };
        };
        x86_64-linux = {
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
