{
  config,
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
  excludedPaths = map (entry: entry.path) manifest.excluded;
  extensionPaths = map (extension: extension.path) manifest.extensions;
  deprecatedTunnel = "scripts/toggle-db-tunnel.sh";

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

  deprecatedTunnelEntries = lib.filter (entry: entry.path == deprecatedTunnel) manifest.excluded;

  scriptCommands = pkgs.linkFarm "raycast-script-commands" (
    map (path: {
      name = targetPath path;
      path = sourcePath path;
    }) managedPaths
  );
in
{
  imports = [ ../../home/common/state-paths.nix ];

  assertions = [
    {
      assertion = manifest.schemaVersion == 1;
      message = "Raycast source manifest must use schema version 1.";
    }
    {
      assertion = builtins.length entrypoints == 8;
      message = "Raycast capability expects exactly eight active Script Command entrypoints.";
    }
    {
      assertion = builtins.length managedPaths == 18 && builtins.length (lib.unique managedPaths) == 18;
      message = "Raycast managed Script Command tree must contain exactly 18 unique source files.";
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
        !(builtins.elem deprecatedTunnel managedPaths)
        && builtins.elem deprecatedTunnel excludedPaths
        && builtins.length deprecatedTunnelEntries == 1
        && (builtins.head deprecatedTunnelEntries).status == "deprecated";
      message = "Deprecated Raycast DB tunnel must be excluded exactly once and never enter the managed tree.";
    }
  ];

  # Raycast must still be pointed at this directory through its official UI.
  # Evaluation and activation never import it into Raycast's database.
  xdg.dataFile."raycast/script-commands" = {
    source = scriptCommands;
    recursive = true;
  };

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.config/raycast";
      owner = "Raycast";
      backup = "separate-policy";
      description = "Writable extension bundles, preferences, local data, and token-bearing config remain outside Nix.";
    }
    {
      path = "${config.home.homeDirectory}/Library/Application Support/com.raycast.macos";
      owner = "Raycast";
      backup = "separate-policy";
      description = "Raycast-owned encrypted databases, activity data, caches, and history remain mutable.";
    }
    {
      path = "${config.home.homeDirectory}/Library/Preferences/com.raycast.macos.plist";
      owner = "Raycast";
      backup = "optional";
      description = "Mixed stable preferences and runtime metadata are not linked to the Nix store.";
    }
  ];
}
