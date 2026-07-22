{ self, ... }:

{
  nixpkgs.hostPlatform = "aarch64-darwin";

  system = {
    primaryUser = "sayori";
    configurationRevision = self.rev or self.dirtyRev or null;

    # This is the current value recommended for a new installation by the
    # pinned nix-darwin module. Keep it unchanged after the first activation.
    stateVersion = 7;
  };

  users.users.sayori = {
    uid = 501;
    home = "/Users/sayori";
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;

    users.sayori = {
      imports = [
        ../../modules/home/common.nix
        ../../modules/home/darwin.nix
      ];

      home = {
        username = "sayori";
        homeDirectory = "/Users/sayori";

        # This is the first Home Manager adoption. The pinned 26.05 manual
        # requires the initial value to remain unchanged after activation.
        stateVersion = "26.05";
      };
    };
  };

  # Preserve the pre-existing macOS sudo_local behavior during adoption.
  security.pam.services.sudo_local.touchIdAuth = true;
}
