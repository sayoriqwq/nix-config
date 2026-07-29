{ lib, ... }:

let
  inherit (lib) mkOption types;
in
{
  options.sayori.shortcuts = mkOption {
    type = types.listOf (
      types.submodule {
        options = {
          scope = mkOption {
            type = types.str;
            description = "User-facing shortcut scope.";
          };
          keys = mkOption {
            type = types.str;
            description = "Key chord or quick command.";
          };
          action = mkOption {
            type = types.str;
            description = "User-visible behavior.";
          };
          owner = mkOption {
            type = types.str;
            description = "Capability module that owns the behavior.";
          };
          order = mkOption {
            type = types.int;
            description = "Stable display order in the generated guide.";
          };
        };
      }
    );
    default = [ ];
    internal = true;
    description = "Minimal metadata contributed by Home Manager capability modules.";
  };
}
