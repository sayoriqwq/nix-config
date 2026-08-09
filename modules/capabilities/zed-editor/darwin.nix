{ config, username, ... }:

let
  homeManagerProfileBin = "${config.home-manager.users.${username}.home.profileDirectory}/bin";
  homeLocalBin = "${config.home-manager.users.${username}.home.homeDirectory}/.local/bin";
  nixProfileBin = "${config.system.primaryUserHome}/.nix-profile/bin";
in
{
  # Home Manager's sessionPath applies to login shells. Zed Nightly.app is
  # launched directly by launchd, so expose the same user-owned profile to
  # GUI processes without touching Zed's writable settings.
  launchd.user.envVariables.PATH = [
    homeManagerProfileBin
    homeLocalBin
    nixProfileBin
    "/run/current-system/sw/bin"
    "/nix/var/nix/profiles/default/bin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
    "/usr/sbin"
    "/sbin"
  ];
}
