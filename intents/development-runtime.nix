{ lib }:

let
  compose = import ./lib.nix { inherit lib; };
  software = {
    direnv = import ../software/direnv;
    mise = import ../software/mise;
    uv = import ../software/uv;
  };
in
compose [
  software.direnv.developmentEnvironment
  software.mise.runtimeManager
  software.uv.pythonPackageManager
]
