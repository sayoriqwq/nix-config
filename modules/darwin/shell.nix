{
  config,
  lib,
  pkgs,
  ...
}:

{
  programs.fish.enable = true;

  users.users = lib.optionalAttrs (config.system.primaryUser != null) {
    ${config.system.primaryUser}.shell = pkgs.fish;
  };
}
