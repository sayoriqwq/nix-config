{
  homeConfiguration,
  pkgs,
}:

let
  inherit (pkgs) lib;
  agent = homeConfiguration.launchd.agents.mos;
  mosPackages = lib.filter (package: (package.pname or (lib.getName package)) == "mos") (
    homeConfiguration.home.packages
  );
  mosApp = "${homeConfiguration.home.homeDirectory}/Applications/Home Manager Apps/Mos.app";
in
assert lib.assertMsg (
  builtins.length mosPackages == 1
) "macbook must have exactly one Nix-owned Mos package";
assert lib.assertMsg agent.enable "macbook must enable the Mos login LaunchAgent";
assert lib.assertMsg (
  agent.domain == "gui"
) "Mos must start in the user's graphical launchd domain";
assert lib.assertMsg agent.waitForNixStore "Mos login startup must wait for the Nix store";
assert lib.assertMsg (
  agent.config.Label == "org.nix-community.home.mos"
) "Mos must use the stable Home Manager launchd label";
assert lib.assertMsg (
  agent.config.ProgramArguments == [
    "/usr/bin/open"
    "-g"
    mosApp
  ]
) "Mos login startup must target the Home Manager Apps bundle";
assert lib.assertMsg agent.config.RunAtLoad "Mos must start when the user logs in";
assert lib.assertMsg (!agent.config.KeepAlive) "launchd must not supervise the Mos GUI process";
assert lib.assertMsg (
  agent.config.ProcessType == "Background"
) "Mos login startup must be classified as a background job";
pkgs.runCommand "macbook-mos-login-check" { } ''
  test -d "${pkgs.mos}/Applications/Mos.app"
  touch "$out"
''
