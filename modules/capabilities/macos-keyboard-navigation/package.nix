{
  defaultsBin ? "/usr/bin/defaults",
  pkgs,
}:

let
  policy = import ./policy.nix;
  policyFile = pkgs.writeText "macos-keyboard-navigation-policy.json" (builtins.toJSON policy);
in
pkgs.writeShellApplication {
  name = "macos-keyboard-navigation";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.jq
  ];
  text = ''
    export MACOS_KEYBOARD_DEFAULTS_BIN=${pkgs.lib.escapeShellArg defaultsBin}
    export MACOS_KEYBOARD_POLICY_FILE=${policyFile}
    ${builtins.readFile ./tool.sh}
  '';
}
