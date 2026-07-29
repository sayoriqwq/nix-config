{ lib, ... }:

{
  options.sayori.statePaths = lib.mkOption {
    type = lib.types.listOf (
      lib.types.submodule {
        options = {
          path = lib.mkOption {
            type = lib.types.str;
            description = "Writable path owned outside the Nix store.";
          };
          owner = lib.mkOption {
            type = lib.types.str;
            description = "Application or workflow that owns the contents.";
          };
          backup = lib.mkOption {
            type = lib.types.enum [
              "required"
              "optional"
              "excluded"
              "separate-policy"
            ];
            description = "Backup boundary for the mutable contents.";
          };
          description = lib.mkOption {
            type = lib.types.str;
            description = "Why the path remains writable and unmanaged by Nix.";
          };
        };
      }
    );
    default = [ ];
    internal = true;
    description = "Auditable declarations of mutable state owned outside Nix.";
  };
}
