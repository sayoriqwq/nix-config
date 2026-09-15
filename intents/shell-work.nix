{ lib }:

let
  compose = import ./lib.nix { inherit lib; };
  fish = import ../software/fish;
in
compose [
  fish.interactiveShell
  {
    homeModules = [
      ../software/git/home-manager.nix
      ../software/atuin/home-manager.nix
      ../software/atuin/zsh-integration.nix
      ../software/pay-respects/home-manager.nix
      ../software/pay-respects/zsh-integration.nix
      ../software/helix/home-manager.nix
      ../software/eza/home-manager.nix
      ../software/eza/zsh-integration.nix
      ../software/fzf/home-manager.nix
      ../software/fzf/zsh-integration.nix
      ../software/starship/home-manager.nix
      ../software/starship/zsh-integration.nix
      ../software/tmux/home-manager.nix
      ../software/zoxide/home-manager.nix
      ../software/zoxide/zsh-integration.nix
      ({ pkgs, ... }: {
        home.packages = with pkgs; [
          fastfetch
          yazi
          fd
          jq
          ripgrep
          tree
        ];
        programs.bat.enable = true;
        programs.btop.enable = true;
        programs.nh.enable = true;
        programs.man.generateCaches = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin false;
        programs.fzf = {
          defaultCommand = "fd";
          defaultOptions = [ "--preview ${lib.escapeShellArg "bat --color=always {}"}" ];
        };
      })
    ];
  }
]
