{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  source = inputs.raycast-source;
  manifest = builtins.fromJSON (builtins.readFile "${source}/raycast-source.json");

  inherit (manifest.scriptCommands) entrypoints supportExecutables supportFiles;

  managedPaths = entrypoints ++ supportExecutables ++ supportFiles;
  extensionPaths = map (extension: extension.path) manifest.extensions;
  retiredPaths = [
    "scripts/toggle-db-tunnel.sh"
    "scripts/yume-switch.sh"
    "scripts/config/yume-switch.json"
  ];

  isSafeRelativePath =
    path: !(lib.hasPrefix "/" path) && !(builtins.elem ".." (lib.splitString "/" path));
  sourcePath = path: "${source}/${path}";
  targetPath = path: lib.removePrefix "scripts/" path;

  extensionMap = builtins.listToAttrs (
    map (extension: {
      name = extension.name;
      value = extension.path;
    }) manifest.extensions
  );
  expectedExtensions = {
    open-in-editor = "extensions/open-in-editor";
    terminal-finder = "extensions/terminal-finder";
  };

  scriptCommands = pkgs.linkFarm "raycast-script-commands" (
    map (path: {
      name = targetPath path;
      path = sourcePath path;
    }) managedPaths
  );
in
{
  assertions = [
    {
      assertion = manifest.schemaVersion == 1;
      message = "Raycast source manifest must use schema version 1.";
    }
    {
      assertion = builtins.length entrypoints == 7;
      message = "Raycast capability expects exactly seven active Script Command entrypoints.";
    }
    {
      assertion = builtins.length managedPaths == 24 && builtins.length (lib.unique managedPaths) == 24;
      message = "Raycast managed Script Command tree must contain exactly 24 unique source files.";
    }
    {
      assertion = lib.all (path: isSafeRelativePath path && lib.hasPrefix "scripts/" path) managedPaths;
      message = "Raycast Script Command manifest paths must remain inside scripts/.";
    }
    {
      assertion = lib.all (path: builtins.pathExists (sourcePath path)) managedPaths;
      message = "Raycast source manifest references a missing Script Command file.";
    }
    {
      assertion =
        lib.all isSafeRelativePath extensionPaths
        && lib.all (path: builtins.pathExists "${source}/${path}/package.json") extensionPaths;
      message = "Raycast source manifest references an unsafe or missing extension directory.";
    }
    {
      assertion = builtins.length manifest.extensions == 2 && extensionMap == expectedExtensions;
      message = "Raycast capability expects only the open-in-editor and terminal-finder source extensions.";
    }
    {
      assertion =
        manifest.excluded == [ ]
        && lib.all (
          path: !(builtins.elem path managedPaths) && !(builtins.pathExists (sourcePath path))
        ) retiredPaths;
      message = "Retired Raycast DB tunnel and Yume files must remain absent from the manifest and source.";
    }
  ];

  # Raycast must still be pointed at this directory through its official UI.
  # Evaluation and activation never import it into Raycast's database.
  xdg.dataFile."raycast/script-commands" = {
    source = scriptCommands;
    recursive = true;
  };

}
