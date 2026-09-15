{ ... }:

{
  programs.lazygit = {
    enable = true;
    enableFishIntegration = true;
    shellWrapperName = "lg";
    settings.keybinding.universal.quitWithoutChangingDirectory = "Q";
  };
}
