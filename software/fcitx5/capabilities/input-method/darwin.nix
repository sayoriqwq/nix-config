{ username, ... }:

{
  # The official Fcitx5.app installer remains the macOS frontend owner. This
  # adapter attaches only declared state boundaries. Input-source registration,
  # preferences, deployment and smoke tests remain exact-commit human gates.
  home-manager.users.${username}.imports = [ ./darwin-home.nix ];
}
