{ config, lib, ... }:

{
  # 普通 GUI 只在登录或任务重新加载时打开；退出应用后不重新拉起。
  launchd.agents =
    lib.mapAttrs
      (_: application: {
        enable = true;
        domain = "gui";
        waitForNixStore = true;
        config = {
          ProgramArguments = [
            "/usr/bin/open"
            "-g"
            application
          ];
          RunAtLoad = true;
          KeepAlive = false;
          ProcessType = "Background";
        };
      })
      {
        clash-verge = "/Applications/Clash Verge.app";
        cleanshot = "/Applications/Setapp/CleanShot X.app";
        hazeover = "/Applications/HazeOver.app";
        mos = "/Applications/Mos.app";
        one-thing = "/Applications/One Thing.app";
        paste = "/Applications/Setapp/Paste.app";
        raycast = "/Applications/Raycast.app";
        setapp = "/Applications/Setapp.app";
        sidenotes = "/Applications/Setapp/SideNotes.app";
        slidepad = "/Applications/Setapp/Slidepad.app";
        tailscale = "/Applications/Tailscale.app";
        timing = "/Applications/Setapp/Timing.app/Contents/Library/LoginItems/TimingHelper.app";
        typeless = "/Applications/Typeless.app";
        vorssaint = "/Applications/Vorssaint.app";
      }
    // {
      # 这是常驻按键探测服务，沿用原任务标识和重启策略。
      nuphy-key-probe = {
        enable = true;
        domain = "gui";
        waitForNixStore = true;
        config = {
          Label = "local.sayori.NuPhyKeyProbe";
          ProgramArguments = [
            "${config.home.homeDirectory}/Applications/NuPhy Key Probe.app/Contents/MacOS/nuphy-key-probe"
            "run"
          ];
          RunAtLoad = true;
          KeepAlive = true;
          ProcessType = "Adaptive";
          ThrottleInterval = 10;
          LowPriorityIO = true;
          StandardOutPath = "${config.home.homeDirectory}/Library/Application Support/NuPhyKeyProbe/launchagent.out.log";
          StandardErrorPath = "${config.home.homeDirectory}/Library/Application Support/NuPhyKeyProbe/launchagent.err.log";
        };
      };
    };
}
