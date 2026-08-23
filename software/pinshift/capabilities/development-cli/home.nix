{
  config,
  lib,
  pkgs,
  ...
}:

let
  defaultCheckout = "${config.home.homeDirectory}/Desktop/remote-location";
  pinshift = pkgs.writeShellApplication {
    name = "pinshift";
    runtimeInputs = [ pkgs.fish ];
    text = ''
      checkout="''${PINSHIFT_CHECKOUT:-${defaultCheckout}}"
      entrypoint="$checkout/bin/pinshift"

      if [[ ! -x "$entrypoint" ]]; then
        echo "Pinshift checkout entrypoint is unavailable: $entrypoint" >&2
        echo "Restore the checkout or set PINSHIFT_CHECKOUT to its new location." >&2
        exit 127
      fi

      exec ${lib.getExe pkgs.fish} "$entrypoint" "$@"
    '';
  };
in
{
  # Nix owns only the stable forwarding command. The mutable checkout,
  # project dependencies, signed build, Keychain identity and device actions
  # remain under Pinshift and explicit user-run workflows.
  home.packages = [ pinshift ];
}
