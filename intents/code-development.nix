{
  lib,
  withVscode ? false,
}:

let
  compose = import ./lib.nix { inherit lib; };
  fish = import ../software/fish;
  zed = import ../software/zed;
in
compose [
  fish.interactiveShell
  zed.guiEditor
  zed.fishQuickCommand
  zed.zshQuickCommand
  {
    darwinModules = lib.optionals withVscode [
      { homebrew.casks = [ "visual-studio-code" ]; }
    ];
    homeModules = [
      ../software/git/home-manager.nix
      ../software/lazygit/home-manager.nix
      ../software/lazygit/zsh-integration.nix
      ({ pkgs, ... }: {
        home.packages = [
          pkgs.nil
          pkgs.nixd
        ];
      })
    ]
    ++ lib.optionals withVscode [
      ../software/vscode/home-manager.nix
      ../software/vscode/shell-command.nix
    ];
  }
  (zed.addTask {
    name = "LazyGit";
    command = "lazygit";
  })
]
