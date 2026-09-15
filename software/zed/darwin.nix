{ config, username, ... }:

let
  homeManagerProfileBin = "${config.home-manager.users.${username}.home.profileDirectory}/bin";
in
{
  # Finder/launchd starts Zed outside a login shell. Expose only the managed
  # user profile and active system generation without touching live Zed state.
  launchd.user.envVariables.PATH = [
    homeManagerProfileBin
    "/run/current-system/sw/bin"
    "/usr/bin"
    "/bin"
    "/usr/sbin"
    "/sbin"
  ];
}
