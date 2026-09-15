{
  lib,
  withMacosDefaults ? false,
}:

{
  homeModules = [
    ../software/direnv/home-manager.nix
    ../software/direnv/zsh-integration.nix
    ../software/mise/home-manager.nix
    ../software/mise/zsh-integration.nix
    ({ pkgs, ... }: {
      # 项目自行管理 Python 版本、虚拟环境、依赖与锁文件。
      home.packages = [ pkgs.uv ];
    })
  ]
  ++ lib.optionals withMacosDefaults [ ../software/mise/macos-defaults.nix ];
}
