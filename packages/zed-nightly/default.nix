args@{
  _7zz ? null,
  alsa-lib ? null,
  autoPatchelfHook ? null,
  fetchurl,
  fetchzip,
  lib,
  makeWrapper ? null,
  nodejs_22 ? null,
  stdenv,
  stdenvNoCC,
}:

# Keep the existing top-level package output path stable while the package
# definition itself is owned by the Zed Software directory.
import ../../software/zed/package.nix args
