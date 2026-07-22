{ lib, ... }:

let
  settings =
    (import ./settings.nix { inherit lib; })
    // (import ./theme.nix)
    // {
      keys = import ./keybindings.nix { inherit lib; };
    };
in
{
  # The macOS application stays owned by nix-darwin's Homebrew cask. Using a
  # plain Home Manager file avoids programs.wezterm, which would install a
  # second WezTerm package from Nixpkgs.
  home.file.".wezterm.lua".text = ''
    local wezterm = require("wezterm")
    local act = wezterm.action

    local config = wezterm.config_builder()
    local nix_settings = ${lib.generators.toLua { } settings}

    for key, value in pairs(nix_settings) do
      config[key] = value
    end

    return config
  '';
}
