{ lib, username, ... }:

{
  # NetworkManager owns its package/service and workstation connection control.
  # Existing mutable connection profiles remain outside Nix declarations; this
  # capability opens no firewall port. Activation can replace the live network
  # path, so service and connectivity readback remain an exact-commit gate.
  networking.networkmanager.enable = true;
  users.users.${username}.extraGroups = lib.mkAfter [ "networkmanager" ];
}
