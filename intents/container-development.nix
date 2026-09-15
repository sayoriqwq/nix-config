{
  # macOS 项目容器运行环境；项目仓库声明 Compose 等运行需求。
  darwinModules = [ { homebrew.casks = [ "orbstack" ]; } ];
  homeModules = [
    ({ lib, ... }: {
      # 容器、虚拟机和数据卷归 OrbStack；这里只接入它生成的 Shell 初始化。
      programs.fish.interactiveShellInit = lib.mkAfter ''
        test -f "$HOME/.orbstack/shell/init2.fish"; and source "$HOME/.orbstack/shell/init2.fish"
      '';
      programs.zsh.profileExtra = ''
        [[ -f "$HOME/.orbstack/shell/init.zsh" ]] && source "$HOME/.orbstack/shell/init.zsh"
      '';
    })
  ];
}
