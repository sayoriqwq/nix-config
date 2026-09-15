{ lib, pkgs, ... }:
let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  editorCommand = import ./command.nix pkgs;
in
{
  # macOS owns its native application; Linux uses the release package.
  # Home Manager merges declared fields into writable files on every activation.
  # Extra fields survive; removing a declaration does not delete live values.
  programs.zed-editor = {
    enable = true;
    package = if isDarwin then null else pkgs.zed-editor;
    mutableUserSettings = true;
    mutableUserKeymaps = true;
    mutableUserTasks = true;
    userSettings = (lib.importJSON ./settings.json) // {
      auto_update = isDarwin;
    };
    userKeymaps = lib.importJSON ./keymap.json;
  };

  home.sessionVariables = {
    EDITOR = "${editorCommand} --wait";
    VISUAL = "${editorCommand} --wait";
  };
}
