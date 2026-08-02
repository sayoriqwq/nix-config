{
  pkgs,
  profilePackages,
}:

let
  python = pkgs.python314;
  profilePythonPackages = pkgs.lib.filter (
    package: builtins.match "^python([0-9.]*)$" (pkgs.lib.getName package) != null
  ) profilePackages;
in
assert pkgs.lib.assertMsg (
  builtins.length profilePythonPackages == 1
) "macbook must expose exactly one baseline Python interpreter";
assert pkgs.lib.assertMsg (
  (builtins.head profilePythonPackages).outPath == python.outPath
) "macbook baseline Python must be pkgs.python314";
pkgs.runCommand "macbook-agent-python" { } ''
  for command in python python3 python3.14; do
    test -x "${python}/bin/$command"
  done

  "${python}/bin/python" -c 'import sys; assert sys.version_info[:2] == (3, 14)'
  touch "$out"
''
