{ username, ... }:

{
  # Capability contract (Darwin): package = platform-local Rime Ice data package;
  # managed configuration = recursive immutable schema leaves and overlay;
  # mutable-state paths = Rime build/userdb/sync/identity files recorded by the
  # Home attachment; services = none; network effects = none; human gate =
  # activation, explicit Rime deploy and real-input smoke.
  home-manager.users.${username}.imports = [ ./home.nix ];
}
