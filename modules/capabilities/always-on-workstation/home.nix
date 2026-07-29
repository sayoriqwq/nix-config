{ lib, ... }:

{
  dconf.settings = {
    "org/gnome/desktop/session".idle-delay = lib.hm.gvariant.mkUint32 0;

    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-timeout = lib.hm.gvariant.mkInt32 0;
      sleep-inactive-ac-type = "nothing";
      sleep-inactive-battery-timeout = lib.hm.gvariant.mkInt32 0;
      sleep-inactive-battery-type = "nothing";
    };
  };
}
