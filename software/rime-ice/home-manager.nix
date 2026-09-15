{
  lib,
  pkgs,
  ...
}:

let
  rimeDataPackage = import ./data-package.nix { inherit lib pkgs; };
in
{
  # Shared Home attachment contract: package = the platform-local filtered Rime
  # Ice data package; managed configuration = recursive immutable data leaves;
  # mutable-state paths = build, userdb, sync and identity files listed below;
  # services = none; network effects = none; human gate = activation/deploy and
  # real input remain separate actions.
  # Rime build output, user databases, sync exports and identity files remain
  # writable. This owner manages only immutable schema leaves.
  xdg.dataFile."fcitx5/rime" = {
    source = "${rimeDataPackage}/share/rime-data";
    recursive = true;
  };
}
