{ pkgs, ... }:

{
  programs.fish.enable = true;

  # nix-darwin deliberately does not mutate an existing administrator's
  # UserShell unless it owns that user through users.knownUsers. Register the
  # stable Nix Fish path here; selecting it is a separately approved chsh step.
  environment.shells = [ pkgs.fish ];
}
