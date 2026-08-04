{ sopsFile }:

{
  config,
  inputs,
  username,
  ...
}:

{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  sops = {
    defaultSopsFile = sopsFile;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    gnupg.sshKeyPaths = [ ];

    secrets.phase11-demo = {
      owner = config.users.users.${username}.name;
      group = config.users.users.${username}.group;
      mode = "0400";
    };
  };

  assertions = [
    {
      assertion = config.sops.secrets.phase11-demo.path == "/run/secrets/phase11-demo";
      message = "phase11 demo secret must stay on the sops-nix runtime path";
    }
  ];
}
