{
  inputs,
  ...
}:

{
  imports = [ inputs.sops-nix.darwinModules.sops ];

  sops = {
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    gnupg.sshKeyPaths = [ ];
  };
}
