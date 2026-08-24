{
  homeManager,
  lib,
  pkgs,
}:

let
  home = homeManager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      ../../software/tailscale/capabilities/stable-workstation-access/darwin-home.nix
      {
        home = {
          username = "stable-access-check";
          homeDirectory = "/tmp/stable-access-check";
          stateVersion = "26.05";
        };
      }
    ];
  };
  fragment = builtins.readFile home.config.home.file.".ssh/config.d/nixbox-tailscale.conf".source;
  forbiddenOwnership = [
    ".ts.net"
    "100."
    "HostName "
    "HostKeyAlias "
    "IdentityFile "
    "StrictHostKeyChecking "
    "User "
  ];
  failures = lib.debug.runTests {
    testExactProxyFragment = {
      expr = fragment;
      expected = ''
        Host nixbox
          ProxyCommand /usr/bin/env TAILSCALE_BE_CLI=1 /Applications/Tailscale.app/Contents/MacOS/Tailscale nc %h %p
      '';
    };
    testExternalEndpointAndIdentityStayExternal = {
      expr = builtins.any (needle: lib.hasInfix needle fragment) forbiddenOwnership;
      expected = false;
    };
  };
in
assert
  lib.debug.throwTestFailures {
    inherit failures;
    description = "Tailscale SSH proxy fragment tests";
  } == null;
pkgs.runCommand "tailscale-ssh-proxy-fragment" { } ''
  touch "$out"
''
