{ pkgs, ... }:

{
  # Capability contract (NixOS): packages = Qt 5/6 Wayland plugins below;
  # managed configuration = package presence only; mutable-state paths = none;
  # services = none; network effects = none; human gate = local Qt native-Wayland
  # and input-method smoke after activation.
  environment.systemPackages = [
    pkgs.qt5.qtwayland
    pkgs.qt6.qtwayland
  ];
}
