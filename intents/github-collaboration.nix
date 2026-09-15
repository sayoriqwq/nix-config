{
  homeModules = [
    ../software/git/home-manager.nix
    ../software/lazygit/home-manager.nix
    ../software/lazygit/zsh-integration.nix
    ../software/gh/git-credential-helper.nix
    ({ pkgs, ... }: {
      # gh 账号和认证状态继续由应用维护。
      home.packages = [
        pkgs.gh
        pkgs.gitleaks
      ];
    })
  ];
}
