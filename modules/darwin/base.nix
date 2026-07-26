{ pkgs, ... }:

{
  # The Lix installer performs the bootstrap. After the first activation,
  # nix-darwin manages the daemon while keeping Lix as the implementation.
  nix = {
    enable = true;
    package = pkgs.lix;

    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];

      # ADR-0006: extend the existing cache set with Zed's signed public
      # cache. This grants no upload capability and keeps signature checks on.
      extra-substituters = [ "https://zed.cachix.org" ];
      extra-trusted-public-keys = [
        "zed.cachix.org-1:/pHQ6dpMsAZk2DiP4WCL0p9YDNKWj2Q5FL20bNmw1cU="
      ];
    };
  };
}
