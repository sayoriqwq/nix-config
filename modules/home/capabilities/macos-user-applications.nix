{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    discord
    iina
    monitorcontrol
    mos
    upscayl
    xbar
  ];

  # Launch the Home Manager-owned Mos bundle at login without letting launchd
  # supervise the GUI application's lifetime. Mos preferences, device state,
  # and macOS privacy grants remain writable application-owned state.
  launchd.agents.mos = {
    enable = true;
    domain = "gui";
    waitForNixStore = true;

    config = {
      ProgramArguments = [
        "/usr/bin/open"
        "-g"
        "${config.home.homeDirectory}/Applications/Home Manager Apps/Mos.app"
      ];
      RunAtLoad = true;
      KeepAlive = false;
      ProcessType = "Background";
    };
  };
}
