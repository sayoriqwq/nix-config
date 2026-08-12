{ config, username, ... }:

let
  homeManagerProfileBin = "${config.home-manager.users.${username}.home.profileDirectory}/bin";
in
{
  # Home Manager's sessionPath applies to login shells. Finder/launchd starts
  # Zed outside that shell environment, so expose the declarative user profile
  # and the active system generation without touching Zed's writable state.
  launchd.user.envVariables.PATH = [
    homeManagerProfileBin
    "/run/current-system/sw/bin"
    "/usr/bin"
    "/bin"
    "/usr/sbin"
    "/sbin"
  ];

  home-manager.users.${username}.imports = [
    ../../home/capabilities/zed-editor.nix
  ];
}
