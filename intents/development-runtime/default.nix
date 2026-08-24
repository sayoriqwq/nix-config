{ lib }:

let
  intentLib = import ../lib.nix;
  software = {
    direnv = import ../../software/direnv { inherit intentLib; };
    mise = import ../../software/mise { inherit intentLib; };
    uv = import ../../software/uv { inherit intentLib; };
  };
in
intentLib.realize (
  lib.pipe intentLib.empty [
    software.direnv.developmentEnvironment
    software.mise.runtimeManager
    software.uv.pythonPackageManager
  ]
)
