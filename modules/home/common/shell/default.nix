{ config, ... }:

{
  imports = [
    ./fish.nix
    ./zsh.nix
  ];

  # Home Manager packages must win over mutable compatibility tools. Keep
  # ~/.local/bin available for user-managed commands that have not migrated.
  home.sessionPath = [
    "${config.home.profileDirectory}/bin"
    "${config.home.homeDirectory}/.local/bin"
  ];

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
