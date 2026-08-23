{ pkgs, ... }:

{
  # The Lix installer performs the bootstrap. After the first activation,
  # nix-darwin manages the daemon while keeping Lix as the implementation.
  nix = {
    enable = true;
    package = pkgs.lix;

    # This repository uses Flakes as its only Nix input mechanism. Keeping
    # nix-darwin's mutable channel compatibility enabled would add a missing
    # root channels directory to NIX_PATH on every shell invocation.
    channel.enable = false;

    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };
}
