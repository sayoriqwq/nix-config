{
  lib,
  pkgs,
  ...
}:

let
  rimeDataPackage = import ./data-package.nix { inherit lib pkgs; };
in
{
  # 只管理不可变方案文件，构建产物、用户词库、同步与身份文件保持可写。
  xdg.dataFile."fcitx5/rime" = {
    source = "${rimeDataPackage}/share/rime-data";
    recursive = true;
  };
}
