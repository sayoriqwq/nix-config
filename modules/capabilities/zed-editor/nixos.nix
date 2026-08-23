{ username, ... }:

{
  home-manager.users.${username}.imports = [
    ../../home/capabilities/zed-editor.nix
  ];
}
