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
  software.direnv.zshIntegration
  software.mise.runtimeManager
  software.mise.zshIntegration
  software.uv.pythonPackageManager
]
