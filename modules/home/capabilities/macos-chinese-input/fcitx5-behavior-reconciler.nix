{
  configAdapter,
  contract,
  lib,
  pkgs,
}:

let
  adapter = lib.getExe configAdapter;
  desiredShareInputState = contract.behavior.desired.global.Behavior.ShareInputState;
  desiredAppDefaultIM = builtins.toJSON contract.behavior.desired.macosfrontend.AppDefaultIM;
  desiredGlobalPayload = builtins.toJSON contract.behavior.desired.global;
  desiredFrontendPayload = builtins.toJSON contract.behavior.desired.macosfrontend;
  keepAltTriggerKeys = builtins.toJSON contract.behavior.keep.global.Hotkey.AltTriggerKeys;
  keepStatusBar = contract.behavior.keep.macosfrontend.StatusBar;
  keepRimeInputState = contract.behavior.keep.rime.InputState;
in
pkgs.writeShellApplication {
  name = "fcitx5-behavior-reconciler";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.jq
  ];
  text = ''
    adapter=${lib.escapeShellArg adapter}
    desired_share_input_state=${lib.escapeShellArg desiredShareInputState}
    desired_app_default_im=${lib.escapeShellArg desiredAppDefaultIM}
    desired_global_payload=${lib.escapeShellArg desiredGlobalPayload}
    desired_frontend_payload=${lib.escapeShellArg desiredFrontendPayload}
    keep_alt_trigger_keys=${lib.escapeShellArg keepAltTriggerKeys}
    keep_status_bar=${lib.escapeShellArg keepStatusBar}
    keep_rime_input_state=${lib.escapeShellArg keepRimeInputState}
    umask 077

    work_root=""
    journal_root=""
    journal_file=""
    journal_tmp=""
    lock_dir=""
    lock_acquired=0

    cleanup() {
      if [[ -n "$journal_tmp" && -e "$journal_tmp" ]]; then
        rm -f -- "$journal_tmp"
      fi
      if [[ "$lock_acquired" -eq 1 ]]; then
        rmdir -- "$lock_dir" 2>/dev/null || true
      fi
      if [[ -n "$work_root" && -d "$work_root" ]]; then
        rm -rf -- "$work_root"
      fi
    }
    trap cleanup EXIT

    fail() {
      echo "fcitx5-behavior-reconciler: $*" >&2
      exit 1
    }

    usage() {
      echo "usage: fcitx5-behavior-reconciler check | reconcile JOURNAL_ROOT | rollback JOURNAL_ROOT" >&2
      exit 64
    }

    validate_global() {
      local file="$1"
      jq -e --argjson keep "$keep_alt_trigger_keys" '
        type == "object"
        and (.Children | type == "array")
        and ([.Children[] | select(type == "object" and .Option? == "Hotkey")] | length == 1)
        and ([.Children[] | select(type == "object" and .Option? == "Behavior")] | length == 1)
        and (
          [.Children[] | select(.Option == "Hotkey") | .Children]
          | (length == 1 and (.[0] | type == "array"))
        )
        and (
          [.Children[] | select(.Option == "Hotkey") | .Children[]
            | select(type == "object" and .Option? == "AltTriggerKeys")]
          | length == 1
        )
        and (
          [.Children[] | select(.Option == "Hotkey") | .Children[]
            | select(.Option == "AltTriggerKeys") | .Value][0] == $keep
        )
        and (
          [.Children[] | select(.Option == "Behavior") | .Children]
          | (length == 1 and (.[0] | type == "array"))
        )
        and (
          [.Children[] | select(.Option == "Behavior") | .Children[]
            | select(type == "object" and .Option? == "ShareInputState")]
          | length == 1
        )
        and (
          [.Children[] | select(.Option == "Behavior") | .Children[]
            | select(.Option == "ShareInputState") | .Value][0]
          | (type == "string" and (. == "No" or . == "All" or . == "Program"))
        )
      ' "$file" >/dev/null
    }

    validate_frontend() {
      local file="$1"
      jq -e --arg keep "$keep_status_bar" '
        def valid_app_entry:
          if type != "string" then
            false
          else
            (try fromjson catch null) as $entry
            | ($entry | type == "object")
              and ($entry | keys == ["appId", "appPath", "imName"])
              and ($entry.appId | type == "string")
              and ($entry.appPath | type == "string")
              and ($entry.imName | type == "string")
          end;
        type == "object"
        and (.Children | type == "array")
        and ([.Children[] | select(type == "object" and .Option? == "StatusBar")] | length == 1)
        and ([.Children[] | select(type == "object" and .Option? == "AppDefaultIM")] | length == 1)
        and ([.Children[] | select(.Option == "StatusBar") | .Value][0] == $keep)
        and (
          [.Children[] | select(.Option == "AppDefaultIM") | .Value][0]
          | (
            . == ""
            or (
              type == "object"
              and all(keys[]; test("^(0|[1-9][0-9]*)$"))
              and all(.[]; valid_app_entry)
            )
          )
        )
      ' "$file" >/dev/null
    }

    validate_rime() {
      local file="$1"
      jq -e --arg keep "$keep_rime_input_state" '
        type == "object"
        and (.Children | type == "array")
        and ([.Children[] | select(type == "object" and .Option? == "InputState")] | length == 1)
        and ([.Children[] | select(.Option == "InputState") | .Value][0] | type == "string")
        and ([.Children[] | select(.Option == "InputState") | .Value][0] == $keep)
      ' "$file" >/dev/null
    }

    read_share_input_state() {
      jq -er '
        [.Children[] | select(.Option == "Behavior") | .Children[]
          | select(.Option == "ShareInputState") | .Value][0]
      ' "$1"
    }

    read_app_default_im() {
      jq -ec '
        [.Children[] | select(.Option == "AppDefaultIM") | .Value][0]
        | if . == "" then {} else . end
      ' "$1"
    }

    fetch_target() {
      local target="$1"
      "$adapter" get "$target" > "$work_root/$target.json"
    }

    validate_target() {
      local target="$1"
      case "$target" in
        global) validate_global "$work_root/global.json" ;;
        macosfrontend) validate_frontend "$work_root/macosfrontend.json" ;;
        rime) validate_rime "$work_root/rime.json" ;;
        *) return 1 ;;
      esac
    }

    fetch_and_validate_target() {
      local target="$1"
      fetch_target "$target" || return 1
      validate_target "$target" || return 1
    }

    fetch_and_validate_all() {
      fetch_and_validate_target global || return 1
      fetch_and_validate_target macosfrontend || return 1
      fetch_and_validate_target rime || return 1
    }

    json_equal() {
      jq -en --argjson left "$1" --argjson right "$2" '$left == $right' >/dev/null
    }

    read_owned_value_json() {
      local target="$1"
      case "$target" in
        global)
          jq -cn --arg value "$(read_share_input_state "$work_root/global.json")" '$value'
          ;;
        macosfrontend)
          read_app_default_im "$work_root/macosfrontend.json"
          ;;
        *)
          return 1
          ;;
      esac
    }

    adapter_set() {
      local target="$1"
      local payload="$2"
      printf '%s' "$payload" | "$adapter" set "$target"
    }

    verify_owned_value_json() {
      local target="$1"
      local expected="$2"
      local current
      fetch_and_validate_target "$target" || return 1
      current="$(read_owned_value_json "$target")" || return 1
      json_equal "$current" "$expected"
    }

    validate_journal_document() {
      local file="$1"
      jq -e \
        --arg globalAfter "$desired_share_input_state" \
        --argjson frontendAfter "$desired_app_default_im" '
        def valid_share_input_state:
          type == "string" and (. == "No" or . == "All" or . == "Program");
        def valid_app_entry:
          if type != "string" then
            false
          else
            (try fromjson catch null) as $entry
            | ($entry | type == "object")
              and ($entry | keys == ["appId", "appPath", "imName"])
              and ($entry.appId | type == "string")
              and ($entry.appPath | type == "string")
              and ($entry.imName | type == "string")
          end;
        def valid_app_default_im:
          type == "object"
          and all(keys[]; test("^(0|[1-9][0-9]*)$"))
          and all(.[]; valid_app_entry);
        .version == 2
        and (.transaction | type == "string" and test("^[0-9]{8}T[0-9]{6}Z-[0-9]+$"))
        and (.status == "prepared"
          or .status == "committed"
          or .status == "rolled-back"
          or .status == "rollback-incomplete")
        and (.changes | type == "array")
        and (.changes | length >= 1 and length <= 2)
        and ([.changes[].target] | unique | length) == (.changes | length)
        and (if .status == "committed" then all(.changes[]; .applied) else true end)
        and all(.changes[];
          (.applied | type == "boolean")
          and (.before != .after)
          and (
            if .target == "global" then
              .path == "Behavior.ShareInputState"
              and (.before | valid_share_input_state)
              and (.after | valid_share_input_state)
              and .after == $globalAfter
            elif .target == "macosfrontend" then
              .path == "AppDefaultIM"
              and (.before | valid_app_default_im)
              and (.after | valid_app_default_im)
              and .after == $frontendAfter
            else
              false
            end
          ))
      ' "$file" >/dev/null
    }

    prepare_journal_root() {
      journal_root="$1"
      [[ "$journal_root" == /* ]] || fail "JOURNAL_ROOT must be an absolute path"
      [[ ! -L "$journal_root" ]] || fail "JOURNAL_ROOT must not be a symlink"
      if [[ ! -e "$journal_root" ]]; then
        mkdir -p -- "$journal_root" || fail "could not create JOURNAL_ROOT"
      fi
      [[ -d "$journal_root" && ! -L "$journal_root" ]] || fail "JOURNAL_ROOT must be a directory"
      [[ "$(stat -c '%u' "$journal_root")" == "$(id -u)" ]] || fail "JOURNAL_ROOT must be owned by the current user"
      [[ "$(stat -c '%a' "$journal_root")" == 700 ]] || fail "JOURNAL_ROOT mode must be 0700"
      journal_file="$journal_root/last-change.json"
      lock_dir="$journal_root/.lock"
    }

    acquire_lock() {
      if ! mkdir -m 0700 -- "$lock_dir"; then
        fail "another Fcitx5 behavior reconciliation holds the journal lock"
      fi
      lock_acquired=1
      [[ ! -L "$lock_dir" ]] || fail "journal lock must not be a symlink"
      [[ "$(stat -c '%u' "$lock_dir")" == "$(id -u)" ]] || fail "journal lock must be owned by the current user"
      [[ "$(stat -c '%a' "$lock_dir")" == 700 ]] || fail "journal lock mode must be 0700"
    }

    inspect_existing_journal() {
      journal_exists=0
      if [[ ! -e "$journal_file" && ! -L "$journal_file" ]]; then
        return 0
      fi
      [[ -f "$journal_file" && ! -L "$journal_file" ]] || fail "existing journal must be a regular file"
      [[ "$(stat -c '%u' "$journal_file")" == "$(id -u)" ]] || fail "existing journal must be owned by the current user"
      [[ "$(stat -c '%a' "$journal_file")" == 600 ]] || fail "existing journal mode must be 0600"
      validate_journal_document "$journal_file" || fail "existing journal is malformed"
      journal_exists=1
    }

    archive_terminal_journal() {
      local status transaction archive
      status="$(jq -r '.status' "$journal_file")" || return 1
      case "$status" in
        committed|rolled-back) ;;
        *) return 1 ;;
      esac
      transaction="$(jq -r '.transaction' "$journal_file")" || return 1
      [[ "$transaction" =~ ^[0-9]{8}T[0-9]{6}Z-[0-9]+$ ]] || return 1
      archive="$journal_root/last-change.$transaction.$status.json"
      [[ ! -e "$archive" && ! -L "$archive" ]] || return 1

      # Hard-link publication is atomic and no-clobber; unlinking the active
      # name afterwards never creates a gap in the rollback evidence.
      ln -- "$journal_file" "$archive" || return 1
      [[ -f "$archive" && ! -L "$archive" ]] || return 1
      [[ "$(stat -c '%u' "$archive")" == "$(id -u)" ]] || return 1
      [[ "$(stat -c '%a' "$archive")" == 600 ]] || return 1
      rm -- "$journal_file" || return 1
      journal_exists=0
    }

    atomic_write_journal() {
      local document="$1"
      [[ ! -d "$journal_file" ]] || return 1
      journal_tmp="$(mktemp "$journal_root/.last-change.json.XXXXXX")" || return 1
      if ! chmod 0600 "$journal_tmp" \
        || ! printf '%s\n' "$document" > "$journal_tmp" \
        || ! validate_journal_document "$journal_tmp" \
        || ! mv -f -- "$journal_tmp" "$journal_file"; then
        rm -f -- "$journal_tmp"
        journal_tmp=""
        return 1
      fi
      journal_tmp=""
      [[ -f "$journal_file" && ! -L "$journal_file" ]] || return 1
      [[ "$(stat -c '%u' "$journal_file")" == "$(id -u)" ]] || return 1
      [[ "$(stat -c '%a' "$journal_file")" == 600 ]] || return 1
    }

    write_prepared_journal() {
      local changes='[]'
      local document transaction
      transaction="$(date -u +%Y%m%dT%H%M%SZ)-$$"

      if [[ "$need_global" -eq 1 ]]; then
        changes="$(jq -cn \
          --argjson changes "$changes" \
          --argjson before "$global_before_value" \
          --argjson after "$global_after_value" \
          '$changes + [{target:"global", path:"Behavior.ShareInputState", before:$before, after:$after, applied:false}]')"
      fi
      if [[ "$need_frontend" -eq 1 ]]; then
        changes="$(jq -cn \
          --argjson changes "$changes" \
          --argjson before "$frontend_before_value" \
          --argjson after "$frontend_after_value" \
          '$changes + [{target:"macosfrontend", path:"AppDefaultIM", before:$before, after:$after, applied:false}]')"
      fi

      document="$(jq -cn \
        --arg transaction "$transaction" \
        --argjson changes "$changes" \
        '{version:2, transaction:$transaction, status:"prepared", changes:$changes}')"
      atomic_write_journal "$document"
    }

    journal_mark_applied() {
      local target="$1"
      local document
      document="$(jq -c --arg target "$target" '
        if ([.changes[] | select(.target == $target)] | length) != 1 then
          error("journal target cardinality mismatch")
        else
          (.changes[] | select(.target == $target) | .applied) = true
        end
      ' "$journal_file")" || return 1
      atomic_write_journal "$document"
    }

    journal_set_status() {
      local status="$1"
      local document
      case "$status" in
        committed|rolled-back|rollback-incomplete) ;;
        *) return 1 ;;
      esac
      document="$(jq -c --arg status "$status" '.status = $status' "$journal_file")" || return 1
      atomic_write_journal "$document"
    }

    rollback_attempted() {
      local failed=0
      local index target before after payload current
      for ((index=''${#attempted_targets[@]} - 1; index >= 0; index--)); do
        target="''${attempted_targets[$index]}"
        case "$target" in
          global)
            before="$global_before_value"
            after="$global_after_value"
            payload="$global_before_payload"
            ;;
          macosfrontend)
            before="$frontend_before_value"
            after="$frontend_after_value"
            payload="$frontend_before_payload"
            ;;
          *)
            failed=1
            continue
            ;;
        esac

        if ! fetch_and_validate_target "$target"; then
          echo "fcitx5-behavior-reconciler: rollback GET failed for $target" >&2
          failed=1
          continue
        fi
        current="$(read_owned_value_json "$target")" || {
          failed=1
          continue
        }

        if json_equal "$current" "$before"; then
          continue
        fi
        if ! json_equal "$current" "$after"; then
          echo "fcitx5-behavior-reconciler: rollback CAS refused third value for $target" >&2
          failed=1
          continue
        fi
        if ! journal_mark_applied "$target"; then
          echo "fcitx5-behavior-reconciler: could not record applied value for $target" >&2
          failed=1
          continue
        fi
        if ! adapter_set "$target" "$payload"; then
          echo "fcitx5-behavior-reconciler: rollback POST failed for $target" >&2
          failed=1
          continue
        fi
        if ! verify_owned_value_json "$target" "$before"; then
          echo "fcitx5-behavior-reconciler: rollback verification failed for $target" >&2
          failed=1
        fi
      done

      if [[ "$failed" -eq 0 ]]; then
        if ! journal_set_status rolled-back; then
          failed=1
          journal_set_status rollback-incomplete || true
        fi
      else
        journal_set_status rollback-incomplete || true
      fi
      return "$failed"
    }

    rollback_journal_transaction() {
      local failed=0
      local count index target before after applied current payload
      count="$(jq -r '.changes | length' "$journal_file")" || return 1

      # Complete the CAS preflight for every item before the first rollback POST.
      for ((index=count - 1; index >= 0; index--)); do
        target="$(jq -r --argjson index "$index" '.changes[$index].target' "$journal_file")"
        before="$(jq -c --argjson index "$index" '.changes[$index].before' "$journal_file")"
        after="$(jq -c --argjson index "$index" '.changes[$index].after' "$journal_file")"
        applied="$(jq -r --argjson index "$index" '.changes[$index].applied' "$journal_file")"
        if ! fetch_and_validate_target "$target"; then
          echo "fcitx5-behavior-reconciler: rollback preflight GET failed for $target" >&2
          failed=1
          continue
        fi
        current="$(read_owned_value_json "$target")" || {
          failed=1
          continue
        }
        if [[ "$applied" == true ]]; then
          if ! json_equal "$current" "$before" && ! json_equal "$current" "$after"; then
            echo "fcitx5-behavior-reconciler: rollback CAS refused third value for $target" >&2
            failed=1
          fi
        elif ! json_equal "$current" "$before"; then
          echo "fcitx5-behavior-reconciler: unapplied journal item is not at its before value for $target" >&2
          failed=1
        fi
      done
      if [[ "$failed" -ne 0 ]]; then
        journal_set_status rollback-incomplete || true
        return 1
      fi

      for ((index=count - 1; index >= 0; index--)); do
        target="$(jq -r --argjson index "$index" '.changes[$index].target' "$journal_file")"
        before="$(jq -c --argjson index "$index" '.changes[$index].before' "$journal_file")"
        after="$(jq -c --argjson index "$index" '.changes[$index].after' "$journal_file")"
        applied="$(jq -r --argjson index "$index" '.changes[$index].applied' "$journal_file")"
        if ! fetch_and_validate_target "$target"; then
          echo "fcitx5-behavior-reconciler: rollback GET failed for $target" >&2
          failed=1
          continue
        fi
        current="$(read_owned_value_json "$target")" || {
          failed=1
          continue
        }
        if [[ "$applied" == false ]]; then
          if ! json_equal "$current" "$before"; then
            echo "fcitx5-behavior-reconciler: unapplied journal item changed after preflight for $target" >&2
            failed=1
          fi
          continue
        fi
        if json_equal "$current" "$before"; then
          continue
        fi
        if ! json_equal "$current" "$after"; then
          echo "fcitx5-behavior-reconciler: rollback CAS refused changed value for $target" >&2
          failed=1
          continue
        fi
        case "$target" in
          global)
            payload="$(jq -cn --argjson value "$before" '{Behavior:{ShareInputState:$value}}')"
            ;;
          macosfrontend)
            payload="$(jq -cn --argjson value "$before" '{AppDefaultIM:$value}')"
            ;;
          *)
            failed=1
            continue
            ;;
        esac
        if ! adapter_set "$target" "$payload"; then
          echo "fcitx5-behavior-reconciler: rollback POST failed for $target" >&2
          failed=1
          continue
        fi
        if ! verify_owned_value_json "$target" "$before"; then
          echo "fcitx5-behavior-reconciler: rollback verification failed for $target" >&2
          failed=1
        fi
      done

      if [[ "$failed" -eq 0 ]]; then
        if ! journal_set_status rolled-back; then
          failed=1
          journal_set_status rollback-incomplete || true
        fi
      else
        journal_set_status rollback-incomplete || true
      fi
      return "$failed"
    }

    abort_with_rollback() {
      local reason="$1"
      if ! rollback_attempted; then
        echo "fcitx5-behavior-reconciler: automatic rollback was incomplete" >&2
      fi
      fail "$reason"
    }

    mode="''${1:-}"
    case "$mode" in
      check)
        [[ "$#" -eq 1 ]] || usage
        ;;
      reconcile)
        [[ "$#" -eq 2 ]] || usage
        prepare_journal_root "$2"
        acquire_lock
        inspect_existing_journal
        ;;
      rollback)
        [[ "$#" -eq 2 ]] || usage
        prepare_journal_root "$2"
        acquire_lock
        inspect_existing_journal
        [[ "$journal_exists" -eq 1 ]] || fail "rollback requires an existing journal"
        case "$(jq -r '.status' "$journal_file")" in
          committed|rollback-incomplete) ;;
          *) fail "rollback requires journal status committed or rollback-incomplete" ;;
        esac
        ;;
      *)
        usage
        ;;
    esac

    work_root="$(mktemp -d)"
    "$adapter" probe || fail "Fcitx5 configuration channel is unavailable"
    fetch_and_validate_all || fail "configuration is missing, duplicated, malformed, or violates a Keep invariant"

    if [[ "$mode" == rollback ]]; then
      rollback_journal_transaction || fail "journal transaction rollback was incomplete"
      exit 0
    fi

    share_before="$(read_share_input_state "$work_root/global.json")"
    frontend_before="$(read_app_default_im "$work_root/macosfrontend.json")"
    global_before_value="$(jq -cn --arg value "$share_before" '$value')"
    global_after_value="$(jq -cn --arg value "$desired_share_input_state" '$value')"
    frontend_before_value="$frontend_before"
    frontend_after_value="$desired_app_default_im"
    global_before_payload="$(jq -cn --arg value "$share_before" '{Behavior:{ShareInputState:$value}}')"
    frontend_before_payload="$(jq -cn --argjson value "$frontend_before" '{AppDefaultIM:$value}')"

    need_global=0
    need_frontend=0
    json_equal "$global_before_value" "$global_after_value" || need_global=1
    json_equal "$frontend_before_value" "$frontend_after_value" || need_frontend=1

    if [[ "$mode" == reconcile && "$journal_exists" -eq 1 ]]; then
      case "$(jq -r '.status' "$journal_file")" in
        prepared|rollback-incomplete)
          fail "existing incomplete journal requires manual recovery"
          ;;
      esac
    fi

    if [[ "$mode" == check ]]; then
      if [[ "$need_global" -ne 0 || "$need_frontend" -ne 0 ]]; then
        fail "owned Fcitx5 behavior has drifted"
      fi
      exit 0
    fi

    if [[ "$need_global" -eq 0 && "$need_frontend" -eq 0 ]]; then
      exit 0
    fi

    if [[ "$journal_exists" -eq 1 ]]; then
      archive_terminal_journal || fail "could not safely archive the previous terminal journal"
    fi
    write_prepared_journal || fail "could not write prepared semantic journal"
    attempted_targets=()

    if [[ "$need_global" -eq 1 ]]; then
      verify_owned_value_json global "$global_before_value" || abort_with_rollback "global configuration changed before reconciliation"
      attempted_targets+=(global)
      adapter_set global "$desired_global_payload" || abort_with_rollback "failed to set Behavior.ShareInputState"
      verify_owned_value_json global "$global_after_value" || abort_with_rollback "Behavior.ShareInputState verification failed"
      journal_mark_applied global || abort_with_rollback "could not journal applied Behavior.ShareInputState"
    fi

    if [[ "$need_frontend" -eq 1 ]]; then
      verify_owned_value_json macosfrontend "$frontend_before_value" || abort_with_rollback "macOS frontend configuration changed before reconciliation"
      attempted_targets+=(macosfrontend)
      adapter_set macosfrontend "$desired_frontend_payload" || abort_with_rollback "failed to clear AppDefaultIM"
      verify_owned_value_json macosfrontend "$frontend_after_value" || abort_with_rollback "AppDefaultIM verification failed"
      journal_mark_applied macosfrontend || abort_with_rollback "could not journal applied AppDefaultIM"
    fi

    fetch_and_validate_all || abort_with_rollback "final Keep-invariant verification failed"
    final_global_value="$(read_owned_value_json global)"
    final_frontend_value="$(read_owned_value_json macosfrontend)"
    if ! json_equal "$final_global_value" "$global_after_value" \
      || ! json_equal "$final_frontend_value" "$frontend_after_value"; then
      abort_with_rollback "final owned-value verification failed"
    fi
    journal_set_status committed || abort_with_rollback "could not commit semantic journal"
  '';
}
