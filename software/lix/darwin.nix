{ pkgs, ... }:

{
  # The Lix installer performs the bootstrap. After the first activation,
  # nix-darwin manages the daemon while keeping Lix as the implementation.
  nix = {
    enable = true;
    package = pkgs.lix;

    # Flakes are the only repository input mechanism. Mutable channel
    # compatibility would add a missing root channels path to NIX_PATH.
    channel.enable = false;

    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };
}
