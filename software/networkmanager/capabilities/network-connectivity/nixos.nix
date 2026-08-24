{ lib, username, ... }:

{
  # Capability contract (NixOS): package = NetworkManager from the NixOS module;
  # managed configuration = service enablement and user group membership;
  # mutable-state paths = connection profiles external to Nix; services =
  # NetworkManager; network effects = live interface/route/DNS control but no
  # firewall port; human gate = exact-commit connectivity and recovery readback.
  networking.networkmanager.enable = true;
  users.users.${username}.extraGroups = lib.mkAfter [ "networkmanager" ];
}
