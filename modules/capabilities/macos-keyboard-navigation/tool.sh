set -euo pipefail

ACCOUNT_HOME="$(/usr/bin/id -P | /usr/bin/cut -d: -f9)"
readonly ACCOUNT_HOME
readonly DEFAULT_SYMBOLIC_DOMAIN="com.apple.symbolichotkeys"
readonly DEFAULT_SYMBOLIC_PLIST="$ACCOUNT_HOME/Library/Preferences/com.apple.symbolichotkeys.plist"
readonly DEFAULT_RAYCAST_PLIST="$ACCOUNT_HOME/Library/Preferences/com.raycast.macos.plist"
readonly DEFAULT_STATE_DIR="$ACCOUNT_HOME/.local/state/nix-config/macos-keyboard-navigation"
readonly SYMBOLIC_DOMAIN="${MACOS_KEYBOARD_NAVIGATION_SYMBOLIC_DOMAIN:-$DEFAULT_SYMBOLIC_DOMAIN}"
readonly SYMBOLIC_PLIST="${MACOS_KEYBOARD_NAVIGATION_SYMBOLIC_PLIST:-$DEFAULT_SYMBOLIC_PLIST}"
readonly RAYCAST_PLIST="${MACOS_KEYBOARD_NAVIGATION_RAYCAST_PLIST:-$DEFAULT_RAYCAST_PLIST}"
readonly STATE_DIR="${MACOS_KEYBOARD_NAVIGATION_STATE_DIR:-$DEFAULT_STATE_DIR}"
readonly SKIP_PROCESS_CHECK="${MACOS_KEYBOARD_NAVIGATION_SKIP_PROCESS_CHECK:-0}"
readonly DEFAULTS_BIN="${MACOS_KEYBOARD_DEFAULTS_BIN:?the defaults adapter path was not injected}"
readonly POLICY_FILE="${MACOS_KEYBOARD_POLICY_FILE:?the immutable policy path was not injected}"
readonly LOCK_DIR="$STATE_DIR/operation.lock"

WORK_DIR=""
RECEIPT_TEMP=""
LOCK_HELD=0

usage() {
  echo "usage: macos-keyboard-navigation audit|reconcile [--expect-changed ID[,ID...]]|rollback|policy" >&2
  exit 64
}

message() {
  printf 'macos-keyboard-navigation: %s\n' "$*" >&2
}

cleanup() {
  if [[ -n "$RECEIPT_TEMP" && -f "$RECEIPT_TEMP" && ! -L "$RECEIPT_TEMP" ]]; then
    rm -f -- "$RECEIPT_TEMP" || true
  fi
  if [[ -n "$WORK_DIR" && -d "$WORK_DIR" && ! -L "$WORK_DIR" ]]; then
    rm -rf -- "$WORK_DIR" || true
  fi
  if [[ "$LOCK_HELD" -eq 1 ]]; then
    rmdir "$LOCK_DIR" 2>/dev/null || true
  fi
}

trap cleanup EXIT

require_darwin_tools() {
  local tool
  for tool in "$DEFAULTS_BIN" /usr/bin/plutil /usr/bin/pgrep /usr/bin/stat; do
    if [[ ! -x "$tool" ]]; then
      message "required macOS tool is unavailable: $tool"
      return 1
    fi
  done
}

validate_regular_target() {
  local path="$1"
  local label="$2"
  if [[ "$path" != /* ]]; then
    message "$label must be an absolute path: $path"
    return 1
  fi
  if [[ -L "$path" || ! -f "$path" || ! -r "$path" ]]; then
    message "$label must be a readable regular non-symlink file: $path"
    return 1
  fi
}

validate_state_target() {
  if [[ "$STATE_DIR" != /* ]]; then
    message "state directory must be an absolute path: $STATE_DIR"
    return 1
  fi
  if [[ -L "$STATE_DIR" ]]; then
    message "state directory must not be a symbolic link: $STATE_DIR"
    return 1
  fi
  if [[ -e "$STATE_DIR" && ! -d "$STATE_DIR" ]]; then
    message "state directory target is not a directory: $STATE_DIR"
    return 1
  fi
}

validate_target_mode() {
  local canonical_domain_plist canonical_read_plist

  case "$SKIP_PROCESS_CHECK" in
    0)
      if [[ "$SYMBOLIC_DOMAIN" != "$DEFAULT_SYMBOLIC_DOMAIN" ||
        "$SYMBOLIC_PLIST" != "$DEFAULT_SYMBOLIC_PLIST" ||
        "$RAYCAST_PLIST" != "$DEFAULT_RAYCAST_PLIST" ||
        "$STATE_DIR" != "$DEFAULT_STATE_DIR" ]]; then
        message "production mode requires every target to use its exact default"
        return 1
      fi
      if [[ "$DEFAULTS_BIN" != "/usr/bin/defaults" ]]; then
        message "production mode requires the real /usr/bin/defaults adapter"
        return 1
      fi
      ;;
    1)
      if [[ "$SYMBOLIC_DOMAIN" == "$DEFAULT_SYMBOLIC_DOMAIN" ||
        "$SYMBOLIC_PLIST" == "$DEFAULT_SYMBOLIC_PLIST" ||
        "$RAYCAST_PLIST" == "$DEFAULT_RAYCAST_PLIST" ||
        "$STATE_DIR" == "$DEFAULT_STATE_DIR" ]]; then
        message "fixture mode requires every target to be non-default"
        return 1
      fi
      if [[ "$SYMBOLIC_DOMAIN" != /* ]]; then
        message "fixture symbolic domain must be an absolute file domain"
        return 1
      fi
      ;;
    *)
      message "MACOS_KEYBOARD_NAVIGATION_SKIP_PROCESS_CHECK must be 0 or 1"
      return 1
      ;;
  esac

  validate_regular_target "$SYMBOLIC_PLIST" "symbolic hotkey plist" || return 1
  validate_regular_target "$RAYCAST_PLIST" "Raycast plist" || return 1
  validate_state_target || return 1

  if [[ "$SKIP_PROCESS_CHECK" -eq 1 ]]; then
    validate_regular_target "${SYMBOLIC_DOMAIN}.plist" "fixture symbolic domain plist" || return 1
    canonical_domain_plist="$(realpath "${SYMBOLIC_DOMAIN}.plist")" || return 1
    canonical_read_plist="$(realpath "$SYMBOLIC_PLIST")" || return 1
    if [[ "$canonical_domain_plist" != "$canonical_read_plist" ]]; then
      message "fixture symbolic domain and read plist do not identify the same file"
      return 1
    fi
  fi
}

check_process_precondition() {
  if [[ "$SKIP_PROCESS_CHECK" -eq 1 ]]; then
    return 0
  fi
  if /usr/bin/pgrep -x "Raycast" >/dev/null 2>&1; then
    message "Raycast must be closed before reconcile or rollback"
    return 1
  fi
  if /usr/bin/pgrep -x "System Settings" >/dev/null 2>&1; then
    message "System Settings must be closed before reconcile or rollback"
    return 1
  fi
}

ensure_state_dir() {
  local owner mode history_owner history_mode
  umask 077

  mkdir -p "$STATE_DIR"
  if [[ -L "$STATE_DIR" || ! -d "$STATE_DIR" ]]; then
    message "state directory must be a real directory: $STATE_DIR"
    return 1
  fi
  owner="$(/usr/bin/stat -f '%u' "$STATE_DIR")"
  if [[ "$owner" != "$(/usr/bin/id -u)" ]]; then
    message "state directory must be owned by the current user: $STATE_DIR"
    return 1
  fi
  chmod 700 "$STATE_DIR"
  mode="$(/usr/bin/stat -f '%Lp' "$STATE_DIR")"
  [[ "$mode" == "700" ]] || return 1

  if [[ -L "$STATE_DIR/history" ]]; then
    message "history directory must not be a symbolic link: $STATE_DIR/history"
    return 1
  fi
  mkdir -p "$STATE_DIR/history"
  history_owner="$(/usr/bin/stat -f '%u' "$STATE_DIR/history")"
  if [[ "$history_owner" != "$(/usr/bin/id -u)" ]]; then
    message "history directory must be owned by the current user: $STATE_DIR/history"
    return 1
  fi
  chmod 700 "$STATE_DIR/history"
  history_mode="$(/usr/bin/stat -f '%Lp' "$STATE_DIR/history")"
  [[ "$history_mode" == "700" ]] || return 1
}

acquire_operation_lock() {
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    message "operation lock already exists; stale locks require manual inspection: $LOCK_DIR"
    return 1
  fi
  chmod 700 "$LOCK_DIR"
  LOCK_HELD=1
}

new_workspace() {
  WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/macos-keyboard-navigation.XXXXXX")"
  export WORK_DIR
  mkdir -p "$WORK_DIR/before" "$WORK_DIR/after" "$WORK_DIR/cas"
}

leaf_key() {
  printf 'AppleSymbolicHotKeys.%s' "$1"
}

extract_leaf() {
  local id="$1"
  local output="$2"
  /usr/bin/plutil -extract "$(leaf_key "$id")" xml1 -o "$output" "$SYMBOLIC_PLIST" 2>/dev/null
}

leaf_exists() {
  local id="$1"
  /usr/bin/plutil -type "$(leaf_key "$id")" "$SYMBOLIC_PLIST" >/dev/null 2>&1
}

leaf_json() {
  /usr/bin/plutil -convert json -o - "$1" 2>/dev/null | jq -cS .
}

approved_leaf_json() {
  leaf_json "$1" | jq -cS '{enabled, value: {type: .value.type, parameters: .value.parameters}}'
}

validate_hotkey_leaf() {
  local leaf="$1"
  local json
  json="$(leaf_json "$leaf")" || return 1
  jq -e '
    type == "object"
    and (.enabled | type) == "boolean"
    and (.value | type) == "object"
    and (.value.type | type) == "string"
    and .value.type == "standard"
    and (.value.parameters | type) == "array"
    and (.value.parameters | length) == 3
    and all(.value.parameters[]; type == "number" and floor == .)
  ' <<<"$json" >/dev/null
}

leaf_enabled() {
  leaf_json "$1" | jq -er '.enabled | tostring'
}

policy_hotkey27_json() {
  jq -cS '.symbolicHotkeys.hotkey27.desired' "$POLICY_FILE"
}

make_desired_hotkey27() {
  local before="$1"
  local output="$2"
  local json_file="$3"
  local desired
  desired="$(policy_hotkey27_json)"
  leaf_json "$before" | jq --argjson desired "$desired" '
    .enabled = $desired.enabled
    | .value.type = $desired.value.type
    | .value.parameters = $desired.value.parameters
  ' >"$json_file"
  /usr/bin/plutil -convert xml1 -o "$output" "$json_file"
}

make_disabled_leaf() {
  local before="$1"
  local after="$2"
  cp "$before" "$after"
  /usr/bin/plutil -replace enabled -bool false "$after"
}

raycast_audit() {
  local actual_launcher actual_hyper_enabled actual_hyper_include_shift actual_hyper_key_code
  local expected expected_launcher expected_hyper_enabled expected_hyper_include_shift expected_hyper_key_code
  local launcher_matches hyper_matches

  if ! actual_launcher="$(/usr/bin/plutil -extract raycastGlobalHotkey raw -expect string -n -o - "$RAYCAST_PLIST" 2>/dev/null)" ||
    ! actual_hyper_enabled="$(/usr/bin/plutil -extract raycast_hyperKey_state.enabled raw -expect bool -n -o - "$RAYCAST_PLIST" 2>/dev/null)" ||
    ! actual_hyper_include_shift="$(/usr/bin/plutil -extract raycast_hyperKey_state.includeShiftKey raw -expect bool -n -o - "$RAYCAST_PLIST" 2>/dev/null)" ||
    ! actual_hyper_key_code="$(/usr/bin/plutil -extract raycast_hyperKey_state.keyCode raw -expect integer -n -o - "$RAYCAST_PLIST" 2>/dev/null)"; then
    message "Raycast UI-owned gate: approved fields are missing, unreadable, or have unknown types"
    return 1
  fi
  expected="$(jq -cS '.raycast' "$POLICY_FILE")" || return 1

  if ! jq -e '
    (.raycastGlobalHotkey | type) == "string"
    and (.raycast_hyperKey_state.enabled | type) == "boolean"
    and (.raycast_hyperKey_state.includeShiftKey | type) == "boolean"
    and (.raycast_hyperKey_state.keyCode | type) == "number"
    and (.raycast_hyperKey_state.keyCode | floor) == .raycast_hyperKey_state.keyCode
  ' <<<"$expected" >/dev/null; then
    message "immutable Raycast policy has invalid approved-field types"
    return 1
  fi

  expected_launcher="$(jq -r '.raycastGlobalHotkey' <<<"$expected")"
  expected_hyper_enabled="$(jq -r '.raycast_hyperKey_state.enabled' <<<"$expected")"
  expected_hyper_include_shift="$(jq -r '.raycast_hyperKey_state.includeShiftKey' <<<"$expected")"
  expected_hyper_key_code="$(jq -r '.raycast_hyperKey_state.keyCode' <<<"$expected")"

  launcher_matches=false
  hyper_matches=false
  if [[ "$actual_launcher" == "$expected_launcher" ]]; then
    launcher_matches=true
  fi
  if [[ "$actual_hyper_enabled" == "$expected_hyper_enabled" &&
    "$actual_hyper_include_shift" == "$expected_hyper_include_shift" &&
    "$actual_hyper_key_code" == "$expected_hyper_key_code" ]]; then
    hyper_matches=true
  fi

  if [[ "$launcher_matches" != "true" ]]; then
    message "Raycast UI-owned gate drift: launcher must be changed in Raycast Settings"
  fi
  if [[ "$hyper_matches" != "true" ]]; then
    message "Raycast UI-owned gate drift: Hyper key must be enabled without Shift in Raycast Settings"
  fi
  if [[ "$launcher_matches" != "true" || "$hyper_matches" != "true" ]]; then
    return 2
  fi
  message "Raycast UI-owned gate: compliant (read-only)"
}

scan_symbolic_policy() {
  local mode="$1"
  local id before after enabled current_approved desired
  local unknown=0
  local drift=0
  CHANGED_IDS=()
  PRESENT_IDS=()
  ABSENT_IDS=()

  if ! leaf_exists 27; then
    message "managed symbolic hotkey 27 is absent"
    return 1
  fi
  before="$WORK_DIR/before/27.plist"
  after="$WORK_DIR/after/27.plist"
  extract_leaf 27 "$before" || return 1
  validate_hotkey_leaf "$before" || {
    message "managed symbolic hotkey 27 has an unknown structure"
    return 1
  }
  current_approved="$(approved_leaf_json "$before")"
  if ! jq -e --argjson current "$current_approved" '
    [.symbolicHotkeys.hotkey27.acceptedBaselines[]
      | {enabled, value: {type: .value.type, parameters: .value.parameters}}]
    | index($current) != null
  ' "$POLICY_FILE" >/dev/null; then
    message "managed symbolic hotkey 27 is outside the accepted baselines"
    return 1
  fi
  make_desired_hotkey27 "$before" "$after" "$WORK_DIR/hotkey27.json"
  desired="$(policy_hotkey27_json)"
  PRESENT_IDS+=(27)
  if [[ "$current_approved" != "$desired" ]]; then
    CHANGED_IDS+=(27)
    drift=2
    [[ "$mode" == "quiet" ]] || message "managed symbolic hotkey 27: recognizable drift"
  elif [[ "$mode" != "quiet" ]]; then
    message "managed symbolic hotkey 27: compliant"
  fi

  while IFS= read -r id; do
    if ! leaf_exists "$id"; then
      message "required managed symbolic hotkey $id is absent"
      unknown=1
      continue
    fi
    before="$WORK_DIR/before/$id.plist"
    after="$WORK_DIR/after/$id.plist"
    extract_leaf "$id" "$before" || {
      unknown=1
      continue
    }
    if ! validate_hotkey_leaf "$before"; then
      message "required managed symbolic hotkey $id has an unknown structure"
      unknown=1
      continue
    fi
    make_disabled_leaf "$before" "$after"
    PRESENT_IDS+=("$id")
    enabled="$(leaf_enabled "$before")"
    if [[ "$enabled" == "true" ]]; then
      CHANGED_IDS+=("$id")
      drift=2
      [[ "$mode" == "quiet" ]] || message "managed symbolic hotkey $id: recognizable enabled drift"
    elif [[ "$mode" != "quiet" ]]; then
      message "managed symbolic hotkey $id: compliant"
    fi
  done < <(jq -r '.symbolicHotkeys.requiredDisable[]' "$POLICY_FILE")

  while IFS= read -r id; do
    if ! leaf_exists "$id"; then
      ABSENT_IDS+=("$id")
      [[ "$mode" == "quiet" ]] || message "managed symbolic hotkey $id: absent, skipped"
      continue
    fi
    before="$WORK_DIR/before/$id.plist"
    after="$WORK_DIR/after/$id.plist"
    extract_leaf "$id" "$before" || {
      unknown=1
      continue
    }
    if ! validate_hotkey_leaf "$before"; then
      message "optional managed symbolic hotkey $id has an unknown structure"
      unknown=1
      continue
    fi
    make_disabled_leaf "$before" "$after"
    PRESENT_IDS+=("$id")
    enabled="$(leaf_enabled "$before")"
    if [[ "$enabled" == "true" ]]; then
      CHANGED_IDS+=("$id")
      drift=2
      [[ "$mode" == "quiet" ]] || message "managed symbolic hotkey $id: recognizable enabled drift"
    elif [[ "$mode" != "quiet" ]]; then
      message "managed symbolic hotkey $id: compliant"
    fi
  done < <(jq -r '.symbolicHotkeys.disableIfPresent[]' "$POLICY_FILE")

  if [[ "$unknown" -eq 1 ]]; then
    return 1
  fi
  return "$drift"
}

symbolic_audit() {
  new_workspace
  scan_symbolic_policy report
}

audit() {
  local raycast_status=0 symbolic_status=0
  validate_target_mode || return 1
  require_darwin_tools || return 1
  raycast_audit || raycast_status=$?
  symbolic_audit || symbolic_status=$?
  if [[ "$raycast_status" -eq 1 || "$symbolic_status" -eq 1 ]]; then
    return 1
  fi
  if [[ "$raycast_status" -eq 2 || "$symbolic_status" -eq 2 ]]; then
    return 2
  fi
  return 0
}

cas_all_managed_leaves() {
  local id
  for id in "${PRESENT_IDS[@]}"; do
    extract_leaf "$id" "$WORK_DIR/cas/$id.plist" || {
      message "CAS failed: symbolic hotkey $id disappeared"
      return 1
    }
    if ! cmp -s "$WORK_DIR/before/$id.plist" "$WORK_DIR/cas/$id.plist"; then
      message "CAS failed: symbolic hotkey $id changed after inspection"
      return 1
    fi
  done
  for id in "${ABSENT_IDS[@]}"; do
    if leaf_exists "$id"; then
      message "CAS failed: optional symbolic hotkey $id appeared after inspection"
      return 1
    fi
  done
}

target_identity_json() {
  jq -n \
    --arg symbolicDomain "$SYMBOLIC_DOMAIN" \
    --arg symbolicPlist "$SYMBOLIC_PLIST" \
    --arg raycastPlist "$RAYCAST_PLIST" \
    --arg stateDir "$STATE_DIR" \
    '{
      symbolicDomain: $symbolicDomain,
      symbolicPlist: $symbolicPlist,
      raycastPlist: $raycastPlist,
      stateDir: $stateDir
    }'
}

write_active_receipt() {
  local receipt="$STATE_DIR/active.json"
  local entries='[]'
  local id entry

  for id in "${CHANGED_IDS[@]}"; do
    entry="$(jq -n \
      --argjson id "$id" \
      --rawfile beforeXml "$WORK_DIR/before/$id.plist" \
      --rawfile afterXml "$WORK_DIR/after/$id.plist" \
      '{id: $id, beforeXml: $beforeXml, afterXml: $afterXml}')"
    entries="$(jq -c --argjson entry "$entry" '. + [$entry]' <<<"$entries")"
  done

  RECEIPT_TEMP="$(mktemp "$STATE_DIR/.active.json.tmp.XXXXXX")"
  chmod 600 "$RECEIPT_TEMP"
  jq -n \
    --argjson policyVersion "$(jq '.version' "$POLICY_FILE")" \
    --arg createdAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson target "$(target_identity_json)" \
    --argjson leaves "$entries" \
    '{policyVersion: $policyVersion, createdAt: $createdAt, target: $target, leaves: $leaves}' \
    >"$RECEIPT_TEMP"
  sync "$RECEIPT_TEMP"
  mv "$RECEIPT_TEMP" "$receipt"
  RECEIPT_TEMP=""
  sync "$STATE_DIR"
}

defaults_merge_from_files() {
  local side="$1"
  shift
  local id
  local args=()
  for id in "$@"; do
    args+=("$id" "$(<"$WORK_DIR/$side/$id.plist")")
  done
  "$DEFAULTS_BIN" write "$SYMBOLIC_DOMAIN" AppleSymbolicHotKeys -dict-add "${args[@]}"
}

verify_changed_side() {
  local side="$1"
  shift
  local id actual="$WORK_DIR/verify.plist"
  for id in "$@"; do
    extract_leaf "$id" "$actual" || return 1
    if ! cmp -s "$WORK_DIR/$side/$id.plist" "$actual"; then
      message "verification failed for symbolic hotkey $id"
      return 1
    fi
  done
}

parse_expected_changed_ids() {
  local raw="$1"
  local id existing

  if [[ ! "$raw" =~ ^(0|[1-9][0-9]*)(,(0|[1-9][0-9]*))*$ ]]; then
    message "expected changed IDs must be a comma-separated list of canonical integers"
    return 1
  fi
  IFS=',' read -r -a EXPECTED_CHANGED_IDS <<<"$raw"
  for id in "${EXPECTED_CHANGED_IDS[@]}"; do
    if ! jq -e --argjson id "$id" '
      ([27] + .symbolicHotkeys.requiredDisable + .symbolicHotkeys.disableIfPresent)
      | index($id) != null
    ' "$POLICY_FILE" >/dev/null; then
      message "expected changed ID $id is outside the exact managed set"
      return 1
    fi
    for existing in "${VALIDATED_EXPECTED_CHANGED_IDS[@]}"; do
      if [[ "$existing" == "$id" ]]; then
        message "expected changed IDs must not contain duplicates: $id"
        return 1
      fi
    done
    VALIDATED_EXPECTED_CHANGED_IDS+=("$id")
  done
}

format_id_set() {
  local joined
  local IFS=,
  joined="$*"
  printf '[%s]' "$joined"
}

assert_expected_changed_ids() {
  local expected actual found

  if [[ "${#CHANGED_IDS[@]}" -ne "${#VALIDATED_EXPECTED_CHANGED_IDS[@]}" ]]; then
    message "expected changed ID set $(format_id_set "${VALIDATED_EXPECTED_CHANGED_IDS[@]}") does not match observed $(format_id_set "${CHANGED_IDS[@]}"); nothing was written"
    return 1
  fi
  for expected in "${VALIDATED_EXPECTED_CHANGED_IDS[@]}"; do
    found=0
    for actual in "${CHANGED_IDS[@]}"; do
      if [[ "$actual" == "$expected" ]]; then
        found=1
        break
      fi
    done
    if [[ "$found" -ne 1 ]]; then
      message "expected changed ID set $(format_id_set "${VALIDATED_EXPECTED_CHANGED_IDS[@]}") does not match observed $(format_id_set "${CHANGED_IDS[@]}"); nothing was written"
      return 1
    fi
  done
}

reconcile() {
  local enforce_expected_changed="${1:-0}"
  local expected_changed_raw="${2-}"
  local scan_status=0
  validate_target_mode || return 1
  require_darwin_tools || return 1
  EXPECTED_CHANGED_IDS=()
  VALIDATED_EXPECTED_CHANGED_IDS=()
  if [[ "$enforce_expected_changed" -eq 1 ]]; then
    parse_expected_changed_ids "$expected_changed_raw" || return 1
  fi
  check_process_precondition || return 1
  raycast_audit || return $?
  ensure_state_dir || return 1
  acquire_operation_lock || return 1
  if [[ -e "$STATE_DIR/active.json" || -L "$STATE_DIR/active.json" ]]; then
    message "an active receipt already exists; rollback or resolve it first"
    return 1
  fi

  new_workspace
  scan_symbolic_policy quiet || scan_status=$?
  if [[ "$scan_status" -eq 1 ]]; then
    return 1
  fi
  if [[ "$enforce_expected_changed" -eq 1 ]]; then
    assert_expected_changed_ids || return 1
  fi
  if [[ "${#CHANGED_IDS[@]}" -eq 0 ]]; then
    message "managed symbolic hotkeys and the Raycast UI-owned gate are already compliant"
    return 0
  fi

  cas_all_managed_leaves || return 1
  raycast_audit || return $?
  write_active_receipt
  if ! defaults_merge_from_files after "${CHANGED_IDS[@]}"; then
    message "defaults write failed; the active receipt was retained for inspection"
    return 1
  fi
  if ! verify_changed_side after "${CHANGED_IDS[@]}"; then
    message "post-write verification failed; the active receipt was retained"
    return 1
  fi
  message "reconciled ${#CHANGED_IDS[@]} managed symbolic hotkey leaf/leaves; Raycast was not written"
}

validate_receipt_file() {
  local receipt="$1"
  local owner mode policy_version current_target allowed_ids

  if [[ ! -f "$receipt" || -L "$receipt" ]]; then
    message "no regular active receipt is available"
    return 1
  fi
  owner="$(/usr/bin/stat -f '%u' "$receipt")"
  mode="$(/usr/bin/stat -f '%Lp' "$receipt")"
  if [[ "$owner" != "$(/usr/bin/id -u)" || "$mode" != "600" ]]; then
    message "active receipt must be owned by the current user with mode 600"
    return 1
  fi

  if ! jq -e '
    type == "object"
    and (keys == ["createdAt", "leaves", "policyVersion", "target"])
    and (.policyVersion | type) == "number"
    and (.policyVersion | floor) == .policyVersion
    and (.createdAt | type) == "string"
    and (.target | type) == "object"
    and (.target | keys == ["raycastPlist", "stateDir", "symbolicDomain", "symbolicPlist"])
    and all(.target[]; type == "string")
    and (.leaves | type) == "array"
    and (.leaves | length) > 0
    and all(.leaves[];
      type == "object"
      and (keys == ["afterXml", "beforeXml", "id"])
      and (.id | type) == "number"
      and (.id | floor) == .id
      and (.beforeXml | type) == "string"
      and (.afterXml | type) == "string"
    )
    and ([.leaves[].id] | unique | length) == (.leaves | length)
  ' "$receipt" >/dev/null; then
    message "active receipt schema is invalid"
    return 1
  fi

  policy_version="$(jq -c '.version' "$POLICY_FILE")"
  if ! jq -e --argjson version "$policy_version" '.policyVersion == $version' "$receipt" >/dev/null; then
    message "active receipt policy version does not match"
    return 1
  fi
  current_target="$(target_identity_json | jq -cS .)"
  if ! jq -e --argjson target "$current_target" '.target == $target' "$receipt" >/dev/null; then
    message "active receipt target does not match the current target"
    return 1
  fi
  allowed_ids="$(jq -c '[27] + .symbolicHotkeys.requiredDisable + .symbolicHotkeys.disableIfPresent | sort' "$POLICY_FILE")"
  if ! jq -e --argjson allowed "$allowed_ids" '
    all(.leaves[]; (.id as $id | $allowed | index($id) != null))
  ' "$receipt" >/dev/null; then
    message "active receipt contains an ID outside the exact managed set"
    return 1
  fi
}

load_receipt_files() {
  local receipt="$1"
  local id
  RECEIPT_IDS=()
  while IFS= read -r id; do
    RECEIPT_IDS+=("$id")
  done < <(jq -er '.leaves[].id' "$receipt")
  for id in "${RECEIPT_IDS[@]}"; do
    jq -ejr --argjson id "$id" '.leaves[] | select(.id == $id) | .beforeXml' "$receipt" \
      >"$WORK_DIR/before/$id.plist"
    jq -ejr --argjson id "$id" '.leaves[] | select(.id == $id) | .afterXml' "$receipt" \
      >"$WORK_DIR/after/$id.plist"
  done
}

validate_receipt_leaf_semantics() {
  local id before after before_json after_json before_approved after_approved desired
  desired="$(policy_hotkey27_json)"

  for id in "${RECEIPT_IDS[@]}"; do
    before="$WORK_DIR/before/$id.plist"
    after="$WORK_DIR/after/$id.plist"
    if ! validate_hotkey_leaf "$before" || ! validate_hotkey_leaf "$after"; then
      message "active receipt leaf $id has invalid typed plist data"
      return 1
    fi
    before_json="$(leaf_json "$before")"
    after_json="$(leaf_json "$after")"
    before_approved="$(approved_leaf_json "$before")"
    after_approved="$(approved_leaf_json "$after")"

    if [[ "$id" -eq 27 ]]; then
      if ! jq -e --argjson current "$before_approved" '
        [.symbolicHotkeys.hotkey27.acceptedBaselines[]
          | {enabled, value: {type: .value.type, parameters: .value.parameters}}]
        | index($current) != null
      ' "$POLICY_FILE" >/dev/null; then
        message "active receipt hotkey 27 before value is not an accepted baseline"
        return 1
      fi
      if [[ "$after_approved" != "$desired" ]]; then
        message "active receipt hotkey 27 after value is not the desired policy"
        return 1
      fi
      if [[ "$before_approved" == "$desired" ]]; then
        message "active receipt hotkey 27 records a no-op transition"
        return 1
      fi
      if ! jq -en --argjson before "$before_json" --argjson after "$after_json" '
        ($before | del(.enabled, .value.type, .value.parameters))
        == ($after | del(.enabled, .value.type, .value.parameters))
      ' >/dev/null; then
        message "active receipt hotkey 27 changes an unapproved sibling field"
        return 1
      fi
    else
      if ! jq -en --argjson before "$before_json" --argjson after "$after_json" '
        $before.enabled == true
        and $after.enabled == false
        and ($before | del(.enabled)) == ($after | del(.enabled))
      ' >/dev/null; then
        message "active receipt hotkey $id is not a true-to-false enabled-only transition"
        return 1
      fi
    fi
  done
}

rollback() {
  local receipt="$STATE_DIR/active.json"
  local id actual archive
  validate_target_mode || return 1
  require_darwin_tools || return 1
  check_process_precondition || return 1
  ensure_state_dir || return 1
  acquire_operation_lock || return 1
  validate_receipt_file "$receipt" || return 1

  new_workspace
  load_receipt_files "$receipt" || return 1
  validate_receipt_leaf_semantics || return 1
  RESTORE_IDS=()

  for id in "${RECEIPT_IDS[@]}"; do
    actual="$WORK_DIR/cas/$id.plist"
    extract_leaf "$id" "$actual" || {
      message "rollback CAS failed: symbolic hotkey $id is absent"
      return 1
    }
    if cmp -s "$WORK_DIR/after/$id.plist" "$actual"; then
      RESTORE_IDS+=("$id")
    elif cmp -s "$WORK_DIR/before/$id.plist" "$actual"; then
      message "rollback CAS: symbolic hotkey $id is already at its recorded baseline"
    else
      message "rollback CAS failed: symbolic hotkey $id has unknown drift; nothing was written"
      return 1
    fi
  done

  if [[ "${#RESTORE_IDS[@]}" -gt 0 ]]; then
    defaults_merge_from_files before "${RESTORE_IDS[@]}"
  fi
  verify_changed_side before "${RECEIPT_IDS[@]}" || {
    message "rollback verification failed; the active receipt was retained"
    return 1
  }
  archive="$STATE_DIR/history/$(date -u +%Y%m%dT%H%M%SZ)-rollback-$$.json"
  if [[ -e "$archive" || -L "$archive" ]]; then
    message "rollback archive target already exists: $archive"
    return 1
  fi
  mv "$receipt" "$archive"
  sync "$STATE_DIR/history"
  message "rollback resolved ${#RECEIPT_IDS[@]} receipt leaf/leaves; restored ${#RESTORE_IDS[@]}"
}

policy() {
  jq . "$POLICY_FILE"
}

if [[ "$#" -lt 1 ]]; then
  usage
fi

command="$1"
shift

case "$command" in
  audit)
    [[ "$#" -eq 0 ]] || usage
    audit
    ;;
  reconcile)
    if [[ "$#" -eq 0 ]]; then
      reconcile 0
    elif [[ "$#" -eq 2 && "$1" == "--expect-changed" ]]; then
      reconcile 1 "$2"
    else
      usage
    fi
    ;;
  rollback)
    [[ "$#" -eq 0 ]] || usage
    rollback
    ;;
  policy)
    [[ "$#" -eq 0 ]] || usage
    policy
    ;;
  *)
    usage
    ;;
esac
