repo_root=$(git rev-parse --show-toplevel)
package_file="$repo_root/software/zed/package.nix"

usage() {
  cat <<'EOF'
usage: sync-zed-nightly [--release <exact-release>]

Resolve the latest official Zed Nightly release, or use the exact release
provided, verify both workstation artifacts, and update the pinned hashes.
EOF
}

release=""
case "${1:-}" in
  "")
    ;;
  --release)
    if [[ $# -ne 2 ]]; then
      usage >&2
      exit 2
    fi
    release="$2"
    ;;
  --help|-h)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

cd "$repo_root"

if ! git diff --quiet -- "$package_file" || ! git diff --cached --quiet -- "$package_file"; then
  echo "error: $package_file already has changes" >&2
  exit 1
fi

if [[ -z "$release" ]]; then
  latest_url="https://cloud.zed.dev/releases/nightly/latest/download?asset=zed&arch=aarch64&os=macos&source=nix-config"
  resolved_url=$(curl \
    --fail \
    --location \
    --output /dev/null \
    --range 0-0 \
    --show-error \
    --silent \
    --write-out '%{url_effective}' \
    "$latest_url")
  release=${resolved_url%/*}
  release=${release##*/}
fi

if [[ ! "$release" =~ ^[0-9]+\.[0-9]+\.[0-9]+\+nightly\.[0-9]+\.[0-9a-f]{40}$ ]]; then
  echo "error: unexpected Zed Nightly release identity: $release" >&2
  exit 1
fi

release_url="https://cloud.zed.dev/releases/nightly/$release/download"
darwin_url="$release_url?asset=zed&arch=aarch64&os=macos&source=nix-config"
linux_url="$release_url?asset=zed&arch=x86_64&os=linux&source=nix-config"

echo "Prefetching official macOS aarch64 artifact for $release"
darwin_prefetch=$(nix store prefetch-file --json "$darwin_url")
darwin_hash=$(jq --exit-status --raw-output '.hash' <<<"$darwin_prefetch")

echo "Prefetching official Linux x86_64 artifact for $release"
linux_prefetch=$(nix store prefetch-file \
  --json \
  --name zed-linux-x86_64 \
  --unpack \
  "$linux_url")
linux_hash=$(jq --exit-status --raw-output '.hash' <<<"$linux_prefetch")

python3 - "$package_file" "$release" "$darwin_hash" "$linux_hash" <<'PY'
from pathlib import Path
import re
import sys

package_file = Path(sys.argv[1])
release, darwin_hash, linux_hash = sys.argv[2:]
source = package_file.read_text()


def replace_once(pattern: str, replacement: str, text: str) -> str:
    updated, count = re.subn(pattern, replacement, text, count=1)
    if count != 1:
        raise SystemExit(f"expected exactly one match for {pattern!r}, got {count}")
    return updated


source = replace_once(
    r'(?m)^  release = "[^"]+";$',
    f'  release = "{release}";',
    source,
)
source = replace_once(
    r'(?ms)(name = "Zed-aarch64\.dmg";.*?hash = ")[^"]+(";)',
    rf'\g<1>{darwin_hash}\g<2>',
    source,
)
source = replace_once(
    r'(?ms)(name = "zed-linux-x86_64";.*?hash = ")[^"]+(";)',
    rf'\g<1>{linux_hash}\g<2>',
    source,
)

package_file.write_text(source)
PY

nix fmt "$package_file"

echo
echo "Pinned $release with both official artifact hashes."
echo "Review the diff, then run the validation commands in docs/runbooks/update-zed-nightly.md."
git diff -- "$package_file"
