{
  casks,
  lib,
  pkgs,
  scriptCommands,
}:

let
  raycastCasks = lib.filter (cask: (cask.name or null) == "raycast") casks;
  entrypoints = [
    "bilibili-switch.sh"
    "chatgpt-switch.sh"
    "claude-switch.sh"
    "gemini-switch.sh"
    "github-switch.sh"
    "notebook-switch.sh"
    "youtube-switch.sh"
    "yume-switch.sh"
  ];
  supportFiles = [
    "chrome-switch.sh"
    "config/bilibili-switch.json"
    "config/chatgpt-switch.json"
    "config/claude-switch.json"
    "config/gemini-switch.json"
    "config/github-switch.json"
    "config/notebook-switch.json"
    "config/youtube-switch.json"
    "config/yume-switch.json"
    "lib/chrome-switch.js"
  ];
  expectedFiles = entrypoints ++ supportFiles;
in
assert lib.assertMsg (
  builtins.length raycastCasks == 1
) "macbook must have exactly one Raycast Homebrew cask owner";
pkgs.runCommand "macbook-raycast-source-check"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.findutils
    ];
  }
  ''
    ${lib.concatMapStringsSep "\n" (path: ''test -f "${scriptCommands}/${path}"'') expectedFiles}
    ${lib.concatMapStringsSep "\n" (path: ''test -x "${scriptCommands}/${path}"'') (
      entrypoints ++ [ "chrome-switch.sh" ]
    )}

    test ! -e "${scriptCommands}/toggle-db-tunnel.sh"

    fileCount="$(find -L "${scriptCommands}" -type f | wc -l | tr -d '[:space:]')"
    if [ "$fileCount" -ne 18 ]; then
      echo "expected 18 Raycast Script Command files, found $fileCount" >&2
      exit 1
    fi

    touch "$out"
  ''
