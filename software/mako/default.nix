{ intentLib }:

{
  notificationDaemon = intentLib.addModules {
    homeModules = [ ./capabilities/notification-daemon/home.nix ];
  };
}
