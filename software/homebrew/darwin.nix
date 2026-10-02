{ config, lib, ... }:

{
  # 保持 Nix 工具优先，同时让登录环境找到 Homebrew 提供的 CLI。
  environment.systemPath = lib.mkAfter [ "${config.homebrew.prefix}/bin" ];

  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "none";
    };
  };
}
