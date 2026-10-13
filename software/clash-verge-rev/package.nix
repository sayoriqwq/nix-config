{
  pkgs,
  source,
}:

# 只取固定版本的包表达式，依赖仍使用本仓库的 Linux 包集。
let
  package = pkgs.callPackage (source + "/pkgs/by-name/cl/clash-verge-rev/package.nix") { };
in
assert package.version == "2.5.2";
assert package.passthru.service.version == "2.3.3";
package
