{
  # Home Manager 26.05 declares that profiles.default.userSettings accepts a
  # path, but its update-setting merge still treats that path as an attribute
  # set. Enabling the module without profiles also adds an activation script
  # that may create globalStorage. Link only the reviewed JSONC so comments and
  # trailing commas stay byte-for-byte intact without installing an application
  # package or taking ownership of extensions and mutable state.
  home.file."Library/Application Support/Code/User/settings.json".source = ./settings.jsonc;
}
