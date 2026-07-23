{ config, ... }:

{
  imports = [
    ./fish.nix
    ./zsh.nix
  ];

  # Home Manager packages must win over still-installed compatibility
  # packages from platform package managers.
  home.sessionPath = [ "${config.home.profileDirectory}/bin" ];

  sayori.shortcuts = [
    {
      scope = "Fish / Zsh";
      keys = "↑ / ↓";
      action = "按当前输入前缀浏览原生 Shell 历史";
      owner = "shell";
      order = 10;
    }
  ];
}
