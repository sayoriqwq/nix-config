{ lib, username, ... }:

{
  networking.networkmanager.enable = true;
  users.users.${username}.extraGroups = lib.mkAfter [ "networkmanager" ];
}
