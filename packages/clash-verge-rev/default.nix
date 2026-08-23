{
  pkgs,
  source,
}:

# Consume only the reviewed Clash Verge Rev expression from the pinned leaf.
# Its dependencies continue to come from the repository's Linux release set.
let
  package = pkgs.callPackage (source + "/pkgs/by-name/cl/clash-verge-rev/package.nix") { };
in
assert package.version == "2.5.2";
assert package.passthru.service.version == "2.3.3";
package
