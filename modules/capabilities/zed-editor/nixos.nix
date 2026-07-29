{ username, ... }:

{
  # ADR-0006: the Nightly package is built and signed by Zed's public
  # Cachix. Keep this trust attached to the Zed capability so selecting the
  # editor on NixOS does not silently fall back to a full source build.
  nix.settings = {
    extra-substituters = [ "https://zed.cachix.org" ];
    extra-trusted-public-keys = [
      "zed.cachix.org-1:/pHQ6dpMsAZk2DiP4WCL0p9YDNKWj2Q5FL20bNmw1cU="
    ];
  };

  home-manager.users.${username}.imports = [
    ../../home/capabilities/zed-editor.nix
  ];
}
