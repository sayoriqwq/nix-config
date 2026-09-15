{ lib, options, ... }:

let
  hasStructuredHistoryWidget = lib.hasAttrByPath [
    "programs"
    "fzf"
    "historyWidget"
    "command"
  ] options;
in
{
  imports = [
    ./fish-integration.nix
  ];

  programs.fzf = {
    enable = true;
  }
  // lib.optionalAttrs hasStructuredHistoryWidget {
    historyWidget.command = "";
  };

  # Home Manager 26.11 models the history widget directly. The 26.05 module
  # still consumes the legacy environment variable. Both declarations mean
  # "do not bind Ctrl+R": Atuin remains the sole enhanced-history owner.
  home.sessionVariables = lib.optionalAttrs (!hasStructuredHistoryWidget) {
    FZF_CTRL_R_COMMAND = "";
  };
}
