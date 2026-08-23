{ config, ... }:

{
  imports = [
    ../../../software/yume-design/capabilities/terminal-theme/home.nix
    ../common/shortcut-reference.nix
    ../common/state-paths.nix
    ../common/shell/fish.nix
  ];

  home.sessionPath = [
    "${config.home.profileDirectory}/bin"
    "${config.home.homeDirectory}/.local/bin"
  ];

  sayori.shortcuts = [
    {
      scope = "Fish / Zsh";
      keys = "↑ / ↓";
      action = "按当前输入前缀浏览原生 Shell 历史";
      owner = "portable-shell";
      order = 10;
    }
  ];

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.local/share/fish/fish_history";
      owner = "Fish";
      backup = "required";
      description = "Writable native Fish command history.";
    }
    {
      path = "${config.home.homeDirectory}/.config/fish/fish_variables";
      owner = "Fish";
      backup = "optional";
      description = "Writable Fish universal variables; stable shell declarations remain Nix-owned.";
    }
  ];
}
