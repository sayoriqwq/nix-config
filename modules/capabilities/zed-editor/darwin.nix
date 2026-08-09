{ config, username, ... }:

let
  homeManagerProfileBin = "${config.home-manager.users.${username}.home.profileDirectory}/bin";
  homeLocalBin = "${config.home-manager.users.${username}.home.homeDirectory}/.local/bin";
in
{
  # Home Manager's sessionPath applies to login shells. Zed Nightly.app is
  # launched directly by launchd, so expose the declarative user profile and
  # low-priority compatibility path to GUI processes without touching Zed's
  # writable settings. Nix tooling comes from the active system generation,
  # not mutable legacy user or bootstrap profiles.
  launchd.user.envVariables.PATH = [
    homeManagerProfileBin
    homeLocalBin
    "/run/current-system/sw/bin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
    "/usr/sbin"
    "/sbin"
  ];
}
