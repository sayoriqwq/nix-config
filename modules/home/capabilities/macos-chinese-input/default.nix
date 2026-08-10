{
  config,
  inputs,
  lib,
  ...
}:

let
  contract = import ./contract.nix { inherit lib; };
  source = inputs.rime-ice;
  sourcePath = path: "${source}/${path}";
  sourceEntryType =
    path:
    if builtins.pathExists (sourcePath path) then
      let
        directory = builtins.dirOf path;
        basename = builtins.baseNameOf path;
      in
      (builtins.readDir "${source}/${directory}").${basename}
    else
      null;
  managedDataFiles = builtins.listToAttrs (
    map (path: {
      name = "fcitx5/rime/${path}";
      value.source = sourcePath path;
    }) contract.managedPaths
  );
  statePaths = map (
    entry:
    (builtins.removeAttrs entry [ "relativePath" ])
    // {
      path = "${config.home.homeDirectory}/${entry.relativePath}";
    }
  ) contract.mutableStatePaths;
in
{
  imports = [ ../../common/state-paths.nix ];

  assertions = [
    {
      assertion =
        builtins.length contract.managedPaths == contract.expectedManagedPathCount
        && builtins.length (lib.unique contract.managedPaths) == contract.expectedManagedPathCount;
      message = "macOS Chinese input capability expects exactly 65 unique Rime Ice source leaves.";
    }
    {
      assertion = lib.all contract.isSafeRelativePath contract.managedPaths;
      message = "Rime Ice managed paths must be normalized safe relative paths.";
    }
    {
      assertion = lib.all (path: !(contract.isForbiddenManagedPath path)) contract.managedPaths;
      message = "Rime Ice managed paths must exclude build, sync, user databases, runtime identity, and Squirrel patches.";
    }
    {
      assertion = lib.all (path: builtins.pathExists (sourcePath path)) contract.managedPaths;
      message = "The pinned Rime Ice source is missing a reviewed static leaf.";
    }
    {
      assertion = lib.all (path: sourceEntryType path == "regular") contract.managedPaths;
      message = "Every reviewed Rime Ice source leaf must be a regular non-symlink file.";
    }
  ];

  # The parent user-data tree stays writable. Only these reviewed source leaves
  # are linked into it; Fcitx5.app, its plugin payload, and runtime state remain
  # externally owned and are never installed or mutated by this capability.
  xdg.dataFile = managedDataFiles;

  sayori.statePaths = statePaths;
}
