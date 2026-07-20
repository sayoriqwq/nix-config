{ pkgs, ... }:

{
  # The Lix installer performs the bootstrap. After the first activation,
  # nix-darwin manages the daemon while keeping Lix as the implementation.
  nix = {
    enable = true;
    package = pkgs.lix;

    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };
}
