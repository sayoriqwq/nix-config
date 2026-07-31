{
  phase9Pkgs,
  serverConfiguration,
  username,
}:

let
  lib = phase9Pkgs.lib;
  values = import ./values.nix;
  testConfiguration = serverConfiguration.extendModules {
    modules = [
      {
        _module.args.phase9ConfigureWithoutCarrier = false;
        _module.args.phase9NetworkDriver = "virtio_net";
      }
      ./server-overlay.nix
    ];
  };
  config = testConfiguration.config;
  network = config.systemd.network.networks."10-phase9-uplink";
  userKeys = config.users.users.${username}.openssh.authorizedKeys.keys;
  rootKeys = config.users.users.root.openssh.authorizedKeys.keys;
  homeConfig = config.home-manager.users.${username};
  homePackageNames = map lib.getName homeConfig.home.packages;
  forbiddenHomePackages = [
    "gh"
    "google-chrome"
    "obsidian"
    "zed-editor"
  ];
  evidence = {
    addresses = map (address: address.Address) network.addresses;
    configureWithoutCarrier = network.networkConfig.ConfigureWithoutCarrier;
    dns = network.networkConfig.DNS;
    firewall = {
      tcp = config.networking.firewall.allowedTCPPorts;
      udp = config.networking.firewall.allowedUDPPorts;
    };
    hostName = config.networking.hostName;
    networkNames = builtins.attrNames config.systemd.network.networks;
    routes = map (route: {
      inherit (route) Gateway;
      GatewayOnLink = route.GatewayOnLink or false;
    }) network.routes;
    ssh = {
      inherit rootKeys userKeys;
      inherit (config.services.openssh.settings)
        KbdInteractiveAuthentication
        PasswordAuthentication
        PermitRootLogin
        ;
    };
    stateVersion = {
      home = homeConfig.home.stateVersion;
      system = config.system.stateVersion;
    };
  };
in
assert
  evidence.addresses == [
    values.ipv4Address
    values.ipv6Address
  ];
assert !evidence.configureWithoutCarrier;
assert
  evidence.dns == [
    values.ipv4Dns
    values.ipv6Dns
  ];
assert
  evidence.firewall == {
    tcp = [ 22 ];
    udp = [ ];
  };
assert evidence.hostName == "server-phase9";
assert evidence.networkNames == [ "10-phase9-uplink" ];
assert
  evidence.routes == [
    {
      Gateway = values.ipv4Gateway;
      GatewayOnLink = false;
    }
    {
      Gateway = values.ipv6Gateway;
      GatewayOnLink = true;
    }
  ];
assert
  evidence.ssh == {
    KbdInteractiveAuthentication = false;
    PasswordAuthentication = false;
    PermitRootLogin = "prohibit-password";
    rootKeys = [ values.maintenancePublicKey ];
    userKeys = [
      values.maintenancePublicKey
      values.deployPublicKey
    ];
  };
assert
  evidence.stateVersion == {
    home = "26.05";
    system = "26.05";
  };
assert !(homeConfig.programs.atuin.settings ? sync);
assert lib.intersectLists forbiddenHomePackages homePackageNames == [ ];
assert !config.services.xserver.enable;
assert !config.virtualisation.docker.enable;
phase9Pkgs.writeTextDir "phase9-policy.json" (builtins.toJSON evidence)
