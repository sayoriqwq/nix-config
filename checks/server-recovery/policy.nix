{
  installConfiguration,
  pkgs,
  productionConfiguration,
  runner,
  username,
}:

let
  production = productionConfiguration.config;
  installation = installConfiguration.config;
  recoveryTests = production.disko.tests;
  productionKeys = production.users.users.${username}.openssh.authorizedKeys.keys;
  installationKeys = installation.users.users.${username}.openssh.authorizedKeys.keys;
  evidence = {
    firewallTcpPorts = production.networking.firewall.allowedTCPPorts;
    installDisk = installation.disko.devices.disk.main.device;
    installHostName = installation.networking.hostName;
    installTest = builtins.unsafeDiscardStringContext installation.system.build.installTest.drvPath;
    hostName = production.networking.hostName;
    rootLogin = production.services.openssh.settings.PermitRootLogin;
    system = production.nixpkgs.hostPlatform.system;
    toplevel = builtins.unsafeDiscardStringContext production.system.build.toplevel.drvPath;
  };
in
assert recoveryTests.bootCommands == "";
assert recoveryTests.extraChecks == "";
assert recoveryTests.extraConfig == { };
assert production.networking.firewall.allowedTCPPorts == [ 22 ];
assert production.networking.firewall.allowedUDPPorts == [ ];
assert production.services.openssh.settings.PasswordAuthentication == false;
assert production.services.openssh.settings.KbdInteractiveAuthentication == false;
assert production.services.openssh.settings.PermitRootLogin == "no";
assert production.security.sudo.wheelNeedsPassword == false;
assert production.system.stateVersion == "26.05";
assert production.home-manager.users.${username}.home.stateVersion == "26.05";
assert builtins.length productionKeys == 2;
assert installation.networking.hostName == "server-recovery-install";
assert installation.disko.devices.disk.main.device == "/dev/vda";
assert installation.disko.tests.efi == false;
assert builtins.attrNames installation.systemd.network.networks == [ "10-server-recovery-install" ];
assert builtins.length installationKeys == 2;
assert installationKeys != productionKeys;
pkgs.runCommand "server-recovery-policy"
  {
    evidenceJson = builtins.toJSON evidence;
    nativeBuildInputs = [ runner ];
  }
  ''
    set +e
    output="$(server-recovery-test production.example 2>&1)"
    status="$?"
    set -e

    test "$status" -ne 0
    printf '%s\n' "$output" \
      | grep -Fx 'server-recovery-test accepts no target or extra arguments'

    mkdir -p "$out"
    printf '%s\n' "$evidenceJson" > "$out/server-recovery-policy.json"
  ''
