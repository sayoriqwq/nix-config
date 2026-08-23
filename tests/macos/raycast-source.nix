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
  ];
  iconFiles = [
    "icons/bilibili.png"
    "icons/chatgpt.png"
    "icons/claude.png"
    "icons/gemini-notebook-dark.png"
    "icons/gemini-notebook-light.png"
    "icons/gemini.png"
    "icons/github.png"
    "icons/youtube.png"
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
  ]
  ++ iconFiles
  ++ [
    "lib/chrome-switch.js"
  ];
  expectedFiles = entrypoints ++ supportFiles;
  retiredFiles = [
    "toggle-db-tunnel.sh"
    "yume-switch.sh"
    "config/yume-switch.json"
  ];
in
assert lib.assertMsg (
  builtins.length raycastCasks == 1
) "macbook must have exactly one Raycast Homebrew cask owner";
pkgs.runCommand "macbook-raycast-source-check"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.file
      pkgs.findutils
      pkgs.gnugrep
    ];
  }
  ''
    ${lib.concatMapStringsSep "\n" (path: ''test -f "${scriptCommands}/${path}"'') expectedFiles}
    ${lib.concatMapStringsSep "\n" (path: ''test -x "${scriptCommands}/${path}"'') (
      entrypoints ++ [ "chrome-switch.sh" ]
    )}

    ${lib.concatMapStringsSep "\n" (path: ''test ! -e "${scriptCommands}/${path}"'') retiredFiles}

    ${lib.concatMapStringsSep "\n" (path: ''
      iconType="$(file -Lb "${scriptCommands}/${path}")"
      case "$iconType" in
        "PNG image data, 128 x 128"*) ;;
        *)
          echo "expected ${path} to be a 128 x 128 PNG, found: $iconType" >&2
          exit 1
          ;;
      esac
    '') iconFiles}

    grep -Fqx '# @raycast.icon icons/bilibili.png' "${scriptCommands}/bilibili-switch.sh"
    grep -Fqx '# @raycast.icon icons/chatgpt.png' "${scriptCommands}/chatgpt-switch.sh"
    grep -Fqx '# @raycast.icon icons/claude.png' "${scriptCommands}/claude-switch.sh"
    grep -Fqx '# @raycast.icon icons/gemini.png' "${scriptCommands}/gemini-switch.sh"
    grep -Fqx '# @raycast.icon icons/github.png' "${scriptCommands}/github-switch.sh"
    grep -Fqx '# @raycast.icon icons/gemini-notebook-light.png' "${scriptCommands}/notebook-switch.sh"
    grep -Fqx '# @raycast.iconDark icons/gemini-notebook-dark.png' "${scriptCommands}/notebook-switch.sh"
    grep -Fqx '# @raycast.icon icons/youtube.png' "${scriptCommands}/youtube-switch.sh"
    grep -Fqx '# @raycast.title Gemini Notebook (Switch or Open)' "${scriptCommands}/notebook-switch.sh"
    grep -Fq '"notebook.google.com"' "${scriptCommands}/config/notebook-switch.json"
    grep -Fq '"defaultURL": "https://notebook.google.com/"' "${scriptCommands}/config/notebook-switch.json"

    fileCount="$(find -L "${scriptCommands}" -type f | wc -l | tr -d '[:space:]')"
    if [ "$fileCount" -ne 24 ]; then
      echo "expected 24 Raycast Script Command files, found $fileCount" >&2
      exit 1
    fi

    touch "$out"
  ''
