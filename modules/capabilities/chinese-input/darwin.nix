{ username, ... }:

{
  # The official Fcitx5.app installer remains the macOS frontend owner. This
  # adapter attaches only the shared Rime data and Darwin state boundaries.
  home-manager.users.${username}.imports = [ ./darwin-home.nix ];
}
