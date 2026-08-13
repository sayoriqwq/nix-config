{
  lib,
  pkgs,
  rimeDataPackage ? pkgs.rime-ice,
  overlay ? ./default.custom.yaml,
}:

let
  validator = pkgs.writeShellApplication {
    name = "validate-rime-data-root";
    runtimeInputs = [ pkgs.findutils ];
    text = ''
      if [ "$#" -ne 1 ]; then
        echo "usage: validate-rime-data-root DATA_ROOT" >&2
        exit 64
      fi

      source_root="$1"
      if [ ! -d "$source_root" ]; then
        echo "rime-data-validator: data root is not a directory" >&2
        exit 1
      fi

      forbidden_path="$(find "$source_root" \
        -path "$source_root/build" -prune -o \
        \( -name .DS_Store \
        -o -name installation.yaml \
        -o -name squirrel.custom.yaml \
        -o -name sync \
        -o -name user.yaml \
        -o -name '*.userdb' \) \
        -print -quit)"
      if [ -n "$forbidden_path" ]; then
        relative_path="''${forbidden_path#"$source_root"/}"
        echo "rime-data-validator: forbidden mutable path: $relative_path" >&2
        exit 1
      fi

      symbolic_link="$(find "$source_root" \
        -path "$source_root/build" -prune -o \
        -type l -print -quit)"
      if [ -n "$symbolic_link" ]; then
        relative_path="''${symbolic_link#"$source_root"/}"
        echo "rime-data-validator: unsupported symbolic link: $relative_path" >&2
        exit 1
      fi

      if [ -e "$source_root/default.custom.yaml" ] || [ -L "$source_root/default.custom.yaml" ]; then
        echo "rime-data-validator: overlay collision: default.custom.yaml" >&2
        exit 1
      fi
    '';
  };
in
pkgs.runCommand "${lib.getName rimeDataPackage}-data"
  {
    passthru = {
      inherit validator;
      sourcePackage = rimeDataPackage;
    };
  }
  ''
    source_root=${lib.escapeShellArg "${rimeDataPackage}/share/rime-data"}
    data_root="$out/share/rime-data"

    ${lib.getExe validator} "$source_root"

    mkdir -p "$data_root"
    ${pkgs.coreutils}/bin/cp --recursive --symbolic-link "$source_root/." "$data_root/"
    ${pkgs.findutils}/bin/find "$data_root" -type d -exec chmod u+w {} +
    ${pkgs.coreutils}/bin/rm --recursive --force "$data_root/build"
    install -m 0644 ${overlay} "$data_root/default.custom.yaml"

    if [ -e "$data_root/build" ] || [ -L "$data_root/build" ]; then
      echo "rime-data-package: build directory escaped the filter" >&2
      exit 1
    fi
  ''
