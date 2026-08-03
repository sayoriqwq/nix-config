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
        bootstrapTestData = phase10NixboxBootstrap.testData;
        pkgs = phase9Pkgs;
      };
      nixosAnywherePackage = nixos-anywhere.packages.x86_64-linux.nixos-anywhere;
      phase10NixosAnywhere = nixosAnywherePackage.overrideAttrs (oldAttrs: {
        pname = "nixos-anywhere-phase10-strict-host-key";
        postPatch = (oldAttrs.postPatch or "") + ''
          substituteInPlace src/nixos-anywhere.sh \
            --replace-fail \
              'declare -a sshArgs=("-o" "IdentitiesOnly=yes" "-i" "$tempDir/nixos-anywhere" "-o" "UserKnownHostsFile=/dev/null" "-o" "StrictHostKeyChecking=no")' \
              'declare -a sshArgs=("-o" "IdentitiesOnly=yes" "-i" "$tempDir/nixos-anywhere")'
        '';
      });
      phase10ResumeNixosAnywhere = nixosAnywherePackage.overrideAttrs (oldAttrs: {
        pname = "nixos-anywhere-phase10-install-resume-strict-host-key";
        postPatch = (oldAttrs.postPatch or "") + ''
          substituteInPlace src/nixos-anywhere.sh \
            --replace-fail \
              'declare -a sshArgs=("-o" "IdentitiesOnly=yes" "-i" "$tempDir/nixos-anywhere" "-o" "UserKnownHostsFile=/dev/null" "-o" "StrictHostKeyChecking=no")' \
              'declare -a sshArgs=("-o" "IdentitiesOnly=yes" "-i" "$tempDir/nixos-anywhere")'

          substituteInPlace src/nixos-anywhere.sh \
            --replace-fail \
              '  parseArgs "$@"' \
              $'  parseArgs "$@"\n\n  if [[ ''${phases[kexec]} == 1 || ''${phases[disko]} == 1 ]]; then\n    abort "phase10 resume variant permits only install,reboot"\n  fi'

          substituteInPlace src/nixos-anywhere.sh \
            --replace-fail \
              $'  until\n    if [[ ''${envPassword} == y ]]; then\n      HOME="$sshCopyHome" sshpass -e \\\n        ssh-copy-id \\\n        -o ConnectTimeout=10 \\\n        "''${sshArgs[@]}" \\\n        "$sshConnection"\n    else\n      # To override `IdentitiesOnly=yes` set in `sshArgs` we need to set\n      # `IdentitiesOnly=no` first as the first time an SSH option is\n      # specified on the command line takes precedence\n      HOME="$sshCopyHome" ssh-copy-id \\\n        -o IdentitiesOnly=no \\\n        -o ConnectTimeout=10 \\\n        "''${sshArgs[@]}" \\\n        "$sshConnection"\n    fi\n  do\n    sleep 3\n  done' \
              $'  if [[ ''${envPassword} == y ]]; then\n    HOME="$sshCopyHome" sshpass -e \\\n      ssh-copy-id \\\n      -o ConnectTimeout=20 \\\n      "''${sshArgs[@]}" \\\n      "$sshConnection"\n  else\n    # To override `IdentitiesOnly=yes` set in `sshArgs` we need to set\n    # `IdentitiesOnly=no` first as the first time an SSH option is\n    # specified on the command line takes precedence\n    HOME="$sshCopyHome" ssh-copy-id \\\n      -o IdentitiesOnly=no \\\n      -o ConnectTimeout=20 \\\n      "''${sshArgs[@]}" \\\n      "$sshConnection"\n  fi'

          substituteInPlace src/nixos-anywhere.sh \
            --replace-fail \
              $'  step Waiting for the machine to become unreachable due to reboot\n  while runSshTimeout -- exit 0; do sleep 1; done' \
              $'  step Waiting for the machine to become unreachable due to reboot\n  for attempt in {1..12}; do\n    if ! runSshTimeout -- exit 0; then\n      break\n    fi\n    if [[ $attempt == 12 ]]; then\n      abort "machine remained reachable after the bounded reboot wait"\n    fi\n    sleep 5\n  done'
        '';
      });
      phase10InstallResume = import ./tools/phase-10/install-resume.nix {
        inherit username;
        nixosAnywhere = phase10ResumeNixosAnywhere;
        pkgs = phase9Pkgs;
        sourceRevision = self.rev or null;
      };
      phase10InstallResumePolicy = import ./tests/phase-10/install-resume-policy.nix {
        inherit phase10InstallResume;
        nixosAnywhere = phase10ResumeNixosAnywhere;
        pkgs = phase9Pkgs;
      };
      phase10KexecInstaller =
        nixos-anywhere.inputs.nixos-images.packages.x86_64-linux.kexec-installer-nixos-stable-noninteractive;
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
      phase10Install = import ./tools/phase-10/install.nix {
        inherit username;
        kexecInstaller = phase10KexecInstaller;
        nixosAnywhere = phase10NixosAnywhere;
        pkgs = phase9Pkgs;
        serverConfiguration = self.nixosConfigurations.server;
        sourceRevision = self.rev or null;
      };
      phase10InstallPolicy = import ./tests/phase-10/install-policy.nix {
        inherit phase10Install;
        nixosAnywhere = phase10NixosAnywhere;
        pkgs = phase9Pkgs;
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
          phase10-install = phase10Install.install;
          phase10-install-plan = phase10Install.plan;
          phase10-install-resume = phase10InstallResume.install;
          phase10-install-resume-plan = phase10InstallResume.plan;
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
        phase10-install = {
          type = "app";
          program = "${phase10Install.install}/bin/phase10-install";
        };
        phase10-install-plan = {
          type = "app";
          program = "${phase10Install.plan}/bin/phase10-install-plan";
        };
        phase10-install-resume = {
          type = "app";
          program = "${phase10InstallResume.install}/bin/phase10-install-resume";
        };
        phase10-install-resume-plan = {
          type = "app";
          program = "${phase10InstallResume.plan}/bin/phase10-install-resume-plan";
        };
      };

      checks = {
        aarch64-darwin = {
          macbook-agent-python = import ./tests/macos/agent-python.nix {
            pkgs = self.darwinConfigurations.macbook.pkgs;
            profilePackages =
              self.darwinConfigurations.macbook.config.home-manager.users.${username}.home.packages;
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
          macbook-raycast-source = import ./tests/macos/raycast-source.nix {
            inherit (self.darwinConfigurations.macbook.pkgs) lib;
            casks = self.darwinConfigurations.macbook.config.homebrew.casks;
            pkgs = self.darwinConfigurations.macbook.pkgs;
            scriptCommands =
              self.darwinConfigurations.macbook.config.home-manager.users.${username}.xdg.dataFile."raycast/script-commands".source;
          };
          phase10-bootstrap-nixbox = phase10NixboxBootstrap.add;
          phase10-preflight = phase10Preflight;
          phase10-remote-nixbox-bootstrap-shellcheck = phase10RemoteNixboxBootstrapCheck;
          phase10-remote-preflight-shellcheck = phase10RemotePreflightCheck;
          phase10-rollback-nixbox-bootstrap = phase10NixboxBootstrap.remove;
        };
        x86_64-linux = {
          phase9-network = phase9NetworkTest;
          phase9-policy = phase9PolicyCheck;
          phase10-install-policy = phase10InstallPolicy;
          phase10-install-resume-policy = phase10InstallResumePolicy;
          phase10-nixbox-bootstrap = phase10NixboxBootstrapTest;
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
