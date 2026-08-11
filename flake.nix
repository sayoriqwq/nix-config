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

    # Issue #127: preserve the audited Rime Ice behavior during ownership
    # adoption. Upgrades are reviewed separately from this pinned source.
    rime-ice = {
      url = "github:iDvel/rime-ice/a5f5404e369100fcfc5562f86f1205827453e31c";
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

    # Issue #120: consume ax's published package output for macbook only.
    # Keep ax's upstream Nixpkgs/bun2nix graph inside the leaf input.
    ax.url = "github:yusukebe/ax";
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
      macbookPkgs = self.darwinConfigurations.macbook.pkgs;
      macbookHome = self.darwinConfigurations.macbook.config.home-manager.users.${username};
      configurationRevision =
        if self ? rev then
          self.rev
        else if self ? dirtyRev then
          self.dirtyRev
        else
          "";
      rimeIceContract = import ./modules/home/capabilities/macos-chinese-input/contract.nix {
        lib = macbookPkgs.lib;
      };
      macbookFcitx5ConfigAdapter =
        import ./modules/home/capabilities/macos-chinese-input/fcitx5-config-adapter.nix
          {
            lib = macbookPkgs.lib;
            pkgs = macbookPkgs;
          };
      macbookFcitx5BehaviorReconciler =
        import ./modules/home/capabilities/macos-chinese-input/fcitx5-behavior-reconciler.nix
          {
            configAdapter = macbookFcitx5ConfigAdapter;
            contract = rimeIceContract;
            lib = macbookPkgs.lib;
            pkgs = macbookPkgs;
          };
      macbookFcitx5BehaviorRollback = import ./tests/macos/fcitx5-behavior-rollback.nix {
        behaviorReconciler = macbookFcitx5BehaviorReconciler;
        inherit configurationRevision;
        contract = rimeIceContract;
        homeDirectory = macbookHome.home.homeDirectory;
        lib = macbookPkgs.lib;
        pkgs = macbookPkgs;
      };
      macbookRimePreflight = import ./tests/macos/rime-preflight.nix {
        behaviorReconciler = macbookFcitx5BehaviorReconciler;
        contract = rimeIceContract;
        homeDirectory = macbookHome.home.homeDirectory;
        pkgs = macbookPkgs;
        rimeIceSource = inputs.rime-ice;
      };
      macbookRimeOverlayCopy = macbookPkgs.writeText "hm_default.custom.yaml" (
        builtins.readFile rimeIceContract.localOverlay.source
      );
      macbookRimeOverlayDrift = macbookPkgs.writeText "hm_default.custom.yaml" ''
        patch:
          schema_list:
            - schema: luna_pinyin
      '';
      macbookRimePreflightFixture = import ./tests/macos/rime-preflight.nix {
        contract = rimeIceContract;
        checkOverlay = true;
        fixtureMode = true;
        fullCapability = false;
        homeDirectory = "/fixture";
        pkgs = macbookPkgs;
        rimeIceSource = inputs.rime-ice;
      };
      macbookRimePreflightHashDriftFixture = import ./tests/macos/rime-preflight.nix {
        contract = rimeIceContract // {
          localOverlay = rimeIceContract.localOverlay // {
            sha256 = "0000000000000000000000000000000000000000000000000000000000000000";
          };
        };
        checkOverlay = true;
        fixtureMode = true;
        fullCapability = false;
        homeDirectory = "/fixture";
        pkgs = macbookPkgs;
        rimeIceSource = inputs.rime-ice;
      };
      macbookRimePreflightFixtureCheck =
        macbookPkgs.runCommand "macbook-rime-preflight-fixture"
          {
            nativeBuildInputs = [ macbookPkgs.coreutils ];
          }
          ''
            set -euo pipefail
            target_root="$TMPDIR/home/${rimeIceContract.targetRoot}"

            reset_target() {
              rm -rf -- "$TMPDIR/home"
              mkdir -p -- "$target_root"
              ${macbookPkgs.lib.concatMapStringsSep "\n" (path: ''
                mkdir -p -- "$target_root/$(dirname ${macbookPkgs.lib.escapeShellArg path})"
                ln -s -- "${inputs.rime-ice}/${path}" "$target_root/${path}"
              '') rimeIceContract.managedPaths}
            }

            expect_failure() {
              if MACBOOK_RIME_PREFLIGHT_FIXTURE_TARGET_ROOT="$target_root" "$1"; then
                echo "fixture: expected local overlay preflight failure" >&2
                exit 1
              fi
            }

            reset_target
            ln -s -- ${macbookPkgs.lib.escapeShellArg (toString macbookRimeOverlayCopy)} "$target_root/.hm_default.custom.yaml"
            ln -s -- "$target_root/.hm_default.custom.yaml" "$target_root/${rimeIceContract.localOverlay.relativePath}"
            MACBOOK_RIME_PREFLIGHT_FIXTURE_TARGET_ROOT="$target_root" \
              ${macbookPkgs.lib.getExe macbookRimePreflightFixture}

            reset_target
            ln -s -- "$target_root/missing-overlay" "$target_root/${rimeIceContract.localOverlay.relativePath}"
            expect_failure ${macbookPkgs.lib.getExe macbookRimePreflightFixture}

            reset_target
            cp -- ${macbookPkgs.lib.escapeShellArg (toString rimeIceContract.localOverlay.source)} \
              "$target_root/local-copy"
            ln -s -- "$target_root/local-copy" "$target_root/${rimeIceContract.localOverlay.relativePath}"
            expect_failure ${macbookPkgs.lib.getExe macbookRimePreflightFixture}

            reset_target
            ln -s -- ${macbookPkgs.lib.escapeShellArg (toString macbookRimeOverlayDrift)} \
              "$target_root/${rimeIceContract.localOverlay.relativePath}"
            expect_failure ${macbookPkgs.lib.getExe macbookRimePreflightFixture}

            reset_target
            ln -s -- ${macbookPkgs.lib.escapeShellArg (toString macbookRimeOverlayCopy)} \
              "$target_root/${rimeIceContract.localOverlay.relativePath}"
            expect_failure ${macbookPkgs.lib.getExe macbookRimePreflightHashDriftFixture}

            touch "$out"
          '';
      macbookRimePolicy = import ./tests/macos/rime-policy.nix {
        behaviorRollback = macbookFcitx5BehaviorRollback;
        behaviorReconciler = macbookFcitx5BehaviorReconciler;
        contract = rimeIceContract;
        lib = macbookPkgs.lib;
        macbookConfiguration = self.darwinConfigurations.macbook;
        nixboxConfiguration = self.nixosConfigurations.nixbox;
        pkgs = macbookPkgs;
        preflight = macbookRimePreflight;
        rimeIceSource = inputs.rime-ice;
        serverConfiguration = self.nixosConfigurations.server;
        source = ./.;
      };
      macbookFcitx5BehaviorAdapter = import ./tests/macos/fcitx5-behavior-adapter.nix {
        contract = rimeIceContract;
        lib = macbookPkgs.lib;
        pkgs = macbookPkgs;
      };
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
          macbook-fcitx5-behavior-rollback = macbookFcitx5BehaviorRollback;
          macbook-rime-preflight = macbookRimePreflight;
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

      apps.aarch64-darwin = {
        macbook-fcitx5-behavior-rollback = {
          type = "app";
          program = "${macbookFcitx5BehaviorRollback}/bin/macbook-fcitx5-behavior-rollback";
        };
        macbook-rime-preflight = {
          type = "app";
          program = "${macbookRimePreflight}/bin/macbook-rime-preflight";
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
          macbook-rime-preflight-fixture = macbookRimePreflightFixtureCheck;
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
          macbook-mos-login = import ./tests/macos/mos-login.nix {
            homeConfiguration = self.darwinConfigurations.macbook.config.home-manager.users.${username};
            pkgs = self.darwinConfigurations.macbook.pkgs;
          };
          macbook-ai-clients = import ./tests/macos/ai-clients.nix {
            pkgs = self.darwinConfigurations.macbook.pkgs;
            profilePackages =
              self.darwinConfigurations.macbook.config.home-manager.users.${username}.home.packages;
          };
          macbook-ax = import ./tests/macos/ax.nix {
            homeConfiguration = self.darwinConfigurations.macbook.config.home-manager.users.${username};
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
          ghostty-terminal-font-policy = import ./tests/ghostty-terminal/font-policy.nix {
            inherit username;
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
          macbook-rime-policy = macbookRimePolicy;
          macbook-fcitx5-behavior-adapter = macbookFcitx5BehaviorAdapter;
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
