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
  # Home Manager owns only this stable command. The mutable checkout, project
  # dependencies, signed build, Keychain identity, and device operations stay
  # under Pinshift and its explicit user-run workflows.
  home.packages = [ pinshift ];
}
