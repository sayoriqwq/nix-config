repo_root=$(git rev-parse --show-toplevel)
# Keep the existing Flake app wiring stable; the implementation is Zed-owned.
source "$repo_root/software/zed/update.sh"
