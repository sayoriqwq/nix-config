{ username, ... }:

{
  # Capability contract (Darwin): package = none, because the official
  # Fcitx5.app installer owns the frontend; managed configuration = state-path
  # attachment only; mutable-state paths = ~/.config/fcitx5, ~/Library/fcitx5
  # and its cache; services = none declared; network effects = none; human gate
  # = install/update, input-source registration, preferences and input smoke.
  home-manager.users.${username}.imports = [ ./darwin-home.nix ];
}
