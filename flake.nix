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

    # Issue #90: consume only the reviewed source contract. Raycast's own
    # extension tooling remains in the leaf repository, so this is not a Flake.
    raycast-source = {
      url = "github:sayoriqwq/raycast/7b8ac1fee61703b26cc881903e23bc2d73d4ca3a";
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
      clashVergeRevPackage = import ./software/clash-verge-rev/package.nix {
        pkgs = clashVergeRevPkgs;
        source = inputs.clash-verge-rev-package-source;
      };
      serverModules = [
        ./hosts/server
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
      ];
      serverRecoveryOperation = import ./operations/server-recovery {
        inherit
          inputs
          self
          serverModules
          username
          ;
      };
      darwinPkgs = packagesFor "aarch64-darwin";
      fzfConfigureCheck = import ./checks/terminal-work/fzf-configure.nix {
        homeManager = home-manager-darwin;
        inherit (darwinPkgs) lib;
        pkgs = darwinPkgs;
      };
      zoxideZshBehaviorCheck = import ./checks/terminal-work/zoxide-zsh-behavior.nix {
        homeManager = home-manager-darwin;
        pkgs = darwinPkgs;
      };
      zedAddTaskCheck = import ./checks/code-development/zed-add-task.nix {
        homeManager = home-manager-darwin;
        inherit (darwinPkgs) lib;
        pkgs = darwinPkgs;
      };
      zedPackageSelectionCheck = import ./checks/code-development/zed-package-selection.nix {
        inherit darwinPkgs username;
        darwinHomeManager = home-manager-darwin;
        linuxHomeManager = home-manager;
        linuxPkgs = packagesFor "x86_64-linux";
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
      # targets for the narrow Clash seam and Linux Zed Stable.
      packages = {
        x86_64-linux = {
          clash-verge-rev = clashVergeRevPackage;
          zed-stable = (packagesFor "x86_64-linux").zed-editor;
        };
      };

      checks = {
        aarch64-darwin = {
          fzf-configure = fzfConfigureCheck;
          macbook-system = self.darwinConfigurations.macbook.system;
          tailscale-ssh-proxy = tailscaleSshProxyCheck;
          zed-add-task = zedAddTaskCheck;
          zed-package-selection = zedPackageSelectionCheck;
          zoxide-zsh-behavior = zoxideZshBehaviorCheck;
        };
        x86_64-linux = {
          nixbox-system = self.nixosConfigurations.nixbox.config.system.build.toplevel;
          server-system = self.nixosConfigurations.server.config.system.build.toplevel;
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
