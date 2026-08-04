#!/usr/bin/env bash

set -euo pipefail

fail() {
  printf 'phase10-nixbox-bootstrap: %s\n' "$*" >&2
  exit 1
}

if (( $# != 3 )); then
  fail "internal argument contract mismatch"
fi

action="$1"
deploy_key="$2"
macbook_key="$3"

case "$action" in
  add | remove) ;;
  *) fail "unsupported action: $action" ;;
esac

if (( EUID != 0 )); then
  fail "the Ubuntu bootstrap must run as root"
fi

validate_expected_key() {
  local key="$1"
  local expected_comment="$2"
  local key_type
  local key_blob
  local key_comment
  local extra

  IFS=' ' read -r key_type key_blob key_comment extra <<<"$key"
  if [[ "$key_type" != "ssh-ed25519" ]]; then
    fail "expected an ED25519 public key"
  fi
  if [[ ! "$key_blob" =~ ^[A-Za-z0-9+/]+={0,2}$ ]]; then
    fail "public-key payload is not canonical base64"
  fi
  if [[ "$key_comment" != "$expected_comment" || -n "${extra:-}" ]]; then
    fail "public-key comment or field count drifted"
  fi
  if [[ "$key" != "$key_type $key_blob $key_comment" ]]; then
    fail "public key is not in canonical three-field form"
  fi
}

validate_expected_key "$deploy_key" "nixbox-server-deploy-2026-07-30"
validate_expected_key "$macbook_key" "sayori-ecs"

ssh_directory="/root/.ssh"
authorized_keys="$ssh_directory/authorized_keys"

if [[ ! -d "$ssh_directory" || -L "$ssh_directory" ]]; then
  fail "root SSH directory is missing, not a directory, or a symlink"
fi
if [[ ! -f "$authorized_keys" || -L "$authorized_keys" ]]; then
  fail "root authorized_keys is missing, not a regular file, or a symlink"
fi
if [[ "$(stat -c '%a:%U:%G' "$ssh_directory")" != "700:root:root" ]]; then
  fail "root SSH directory mode or ownership drifted"
fi
if [[ "$(stat -c '%a:%U:%G' "$authorized_keys")" != "600:root:root" ]]; then
  fail "root authorized_keys mode or ownership drifted"
fi

command -v ssh-keygen >/dev/null ||
  fail "required validation tool is missing: ssh-keygen"
ssh-keygen -l -f "$authorized_keys" >/dev/null ||
  fail "existing authorized_keys failed ssh-keygen validation"

count_exact_line() {
  local key="$1"
  local file="$2"
  grep -Fxc -- "$key" "$file" || true
}

count_key_payload() {
  local key="$1"
  local file="$2"
  local key_type
  local key_blob

  IFS=' ' read -r key_type key_blob _ <<<"$key"
  awk -v expected_type="$key_type" -v expected_blob="$key_blob" '
    $1 == expected_type && $2 == expected_blob {
      count += 1
    }
    END {
      print count + 0
    }
  ' "$file"
}

macbook_count="$(count_exact_line "$macbook_key" "$authorized_keys")"
macbook_payload_count="$(count_key_payload "$macbook_key" "$authorized_keys")"
deploy_count="$(count_exact_line "$deploy_key" "$authorized_keys")"
deploy_payload_count="$(count_key_payload "$deploy_key" "$authorized_keys")"

if (( macbook_count != 1 || macbook_payload_count != 1 )); then
  fail "the expected macbook root key is not present exactly once"
fi
if (( deploy_count > 1 || deploy_payload_count > 1 )); then
  fail "the nixbox deploy key is duplicated"
fi
if (( deploy_count != deploy_payload_count )); then
  fail "the nixbox deploy key payload exists with unexpected metadata"
fi

case "$action" in
  add)
    expected_deploy_count=1
    if (( deploy_count == 1 )); then
      printf 'phase10-nixbox-bootstrap: action=add changed=no macbook-key=preserved deploy-key-count=1\n'
      exit 0
    fi
    ;;
  remove)
    expected_deploy_count=0
    if (( deploy_count == 0 )); then
      printf 'phase10-nixbox-bootstrap: action=remove changed=no macbook-key=preserved deploy-key-count=0\n'
      exit 0
    fi
    ;;
esac

temporary_file=""
cleanup() {
  if [[ -n "$temporary_file" && -e "$temporary_file" ]]; then
    rm -f -- "$temporary_file"
  fi
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

temporary_file="$(mktemp "$ssh_directory/authorized_keys.phase10.XXXXXX")"
cp --preserve=all -- "$authorized_keys" "$temporary_file"

case "$action" in
  add)
    last_byte=""
    if [[ -s "$temporary_file" ]]; then
      last_byte="$(tail -c 1 "$temporary_file" | od -An -t x1 | tr -d '[:space:]')"
    fi
    if [[ -n "$last_byte" && "$last_byte" != "0a" ]]; then
      printf '\n' >>"$temporary_file"
    fi
    printf '%s\n' "$deploy_key" >>"$temporary_file"
    ;;
  remove)
    awk -v deploy_key="$deploy_key" '$0 != deploy_key { print }' \
      "$authorized_keys" >"$temporary_file"
    ;;
esac

chmod 600 "$temporary_file"
chown root:root "$temporary_file"

if [[ "$(stat -c '%a:%U:%G' "$temporary_file")" != "600:root:root" ]]; then
  fail "candidate authorized_keys mode or ownership is unsafe"
fi
if (( $(count_exact_line "$macbook_key" "$temporary_file") != 1 )); then
  fail "candidate file did not preserve the macbook root key"
fi
if (( $(count_key_payload "$macbook_key" "$temporary_file") != 1 )); then
  fail "candidate file changed the macbook root key payload"
fi
if (( $(count_exact_line "$deploy_key" "$temporary_file") != expected_deploy_count )); then
  fail "candidate file has an unexpected nixbox deploy-key count"
fi
if (( $(count_key_payload "$deploy_key" "$temporary_file") != expected_deploy_count )); then
  fail "candidate file has unexpected nixbox deploy-key metadata"
fi
ssh-keygen -l -f "$temporary_file" >/dev/null ||
  fail "candidate authorized_keys failed ssh-keygen validation"

sync -f "$temporary_file"
mv -f -- "$temporary_file" "$authorized_keys"
temporary_file=""
sync -f "$ssh_directory"

if [[ "$(stat -c '%a:%U:%G' "$authorized_keys")" != "600:root:root" ]]; then
  fail "installed authorized_keys mode or ownership is unsafe"
fi
if (( $(count_exact_line "$macbook_key" "$authorized_keys") != 1 )); then
  fail "installed file did not preserve the macbook root key"
fi
if (( $(count_exact_line "$deploy_key" "$authorized_keys") != expected_deploy_count )); then
  fail "installed file has an unexpected nixbox deploy-key count"
fi

printf 'phase10-nixbox-bootstrap: action=%s changed=yes macbook-key=preserved deploy-key-count=%s\n' \
  "$action" "$expected_deploy_count"
