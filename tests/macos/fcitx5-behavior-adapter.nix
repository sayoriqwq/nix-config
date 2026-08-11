{
  pkgs,
  lib,
  contract,
}:

let
  stableAltTriggerKeys = {
    "0" = "Shift+Shift_L";
    "1" = "Shift+Shift_R";
  };
  stableHotkey = {
    Option = "Hotkey";
    Children = [
      {
        Option = "AltTriggerKeys";
        Value = stableAltTriggerKeys;
      }
    ];
  };
  shareInputState = value: {
    Option = "ShareInputState";
    Value = value;
  };
  behavior = children: {
    Option = "Behavior";
    Children = children;
  };
  statusBar = value: {
    Option = "StatusBar";
    Value = value;
  };
  appDefaultIM = value: {
    Option = "AppDefaultIM";
    Value = value;
  };
  vimMode = {
    Option = "VimMode";
    Value."0" = "org.vim.MacVim";
  };
  terminalAppDefaultIM."0" = builtins.toJSON {
    appPath = "/System/Applications/Utilities/Terminal.app";
    appId = "com.apple.Terminal";
    imName = "keyboard-us";
  };

  initialGlobal = pkgs.writeText "fcitx5-global-drift.json" (
    builtins.toJSON {
      Children = [
        stableHotkey
        (behavior [ (shareInputState "No") ])
      ];
    }
  );
  desiredGlobal = pkgs.writeText "fcitx5-global-desired.json" (
    builtins.toJSON {
      Children = [
        stableHotkey
        (behavior [ (shareInputState "All") ])
      ];
    }
  );
  keepDriftGlobal = pkgs.writeText "fcitx5-global-keep-drift.json" (
    builtins.toJSON {
      Children = [
        {
          Option = "Hotkey";
          Children = [
            {
              Option = "AltTriggerKeys";
              Value."0" = "Shift+Shift_L";
            }
          ];
        }
        (behavior [ (shareInputState "No") ])
      ];
    }
  );
  duplicateOwnedGlobal = pkgs.writeText "fcitx5-global-duplicate-owned.json" (
    builtins.toJSON {
      Children = [
        stableHotkey
        (behavior [
          (shareInputState "No")
          (shareInputState "All")
        ])
      ];
    }
  );
  initialFrontend = pkgs.writeText "fcitx5-frontend-drift.json" (
    builtins.toJSON {
      Children = [
        (statusBar "Hidden")
        (appDefaultIM terminalAppDefaultIM)
        vimMode
      ];
    }
  );
  desiredFrontend = pkgs.writeText "fcitx5-frontend-desired.json" (
    builtins.toJSON {
      Children = [
        (statusBar "Hidden")
        (appDefaultIM "")
        vimMode
      ];
    }
  );
  malformedOwnedFrontend = pkgs.writeText "fcitx5-frontend-malformed-owned.json" (
    builtins.toJSON {
      Children = [
        (statusBar "Hidden")
        (appDefaultIM [ ])
        vimMode
      ];
    }
  );
  malformedEntryFrontend = pkgs.writeText "fcitx5-frontend-malformed-entry.json" (
    builtins.toJSON {
      Children = [
        (statusBar "Hidden")
        (appDefaultIM { "0" = "not-json"; })
        vimMode
      ];
    }
  );
  duplicateKeepFrontend = pkgs.writeText "fcitx5-frontend-duplicate-keep.json" (
    builtins.toJSON {
      Children = [
        (statusBar "Hidden")
        (statusBar "Hidden")
        (appDefaultIM terminalAppDefaultIM)
        vimMode
      ];
    }
  );
  initialRime = pkgs.writeText "fcitx5-rime-stable.json" (
    builtins.toJSON {
      Children = [
        {
          Option = "InputState";
          Value = "All";
        }
      ];
    }
  );
  malformedKeepRime = pkgs.writeText "fcitx5-rime-malformed-keep.json" (
    builtins.toJSON {
      Children = [
        {
          Option = "InputState";
          Value = 1;
        }
      ];
    }
  );

  fakeCurl = pkgs.writeShellApplication {
    name = "fake-fcitx5-curl";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      : "''${FCITX_CLIENT_LOG:?FCITX_CLIENT_LOG is required}"
      endpoint="''${1:?endpoint is required}"
      shift
      payload="$(cat)"
      printf '%s\t%s\n' "$endpoint" "$payload" >> "$FCITX_CLIENT_LOG"
    '';
  };
  productionAdapter =
    import ../../modules/home/capabilities/macos-chinese-input/fcitx5-config-adapter.nix
      {
        fcitx5Curl = lib.getExe fakeCurl;
        inherit lib pkgs;
      };

  fakeAdapter = pkgs.writeShellApplication {
    name = "fake-fcitx5-config-adapter";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      : "''${FCITX_FIXTURE_ROOT:?FCITX_FIXTURE_ROOT is required}"

      verb="''${1:-}"
      target="''${2:-}"
      case "$verb" in
        probe)
          test "$#" -eq 1
          if test "''${FCITX_FAIL_PROBE:-0}" = 1; then
            echo "fixture: injected probe failure" >&2
            exit 1
          fi
          ;;
        get)
          test "$#" -eq 2
          count_file="$FCITX_FIXTURE_ROOT/.get-count-$target"
          get_count=0
          if test -f "$count_file"; then
            get_count="$(cat "$count_file")"
          fi
          get_count="$((get_count + 1))"
          printf '%s\n' "$get_count" > "$count_file"
          if test "$target" = global \
            && test "''${FCITX_DRIFT_GLOBAL_ON_GET:-0}" -eq "$get_count"; then
            jq '
              (.Children[] | select(.Option == "Behavior")
                | .Children[] | select(.Option == "ShareInputState") | .Value)
                = "Program"
            ' "$FCITX_FIXTURE_ROOT/global.json" > "$FCITX_FIXTURE_ROOT/global.next"
            mv "$FCITX_FIXTURE_ROOT/global.next" "$FCITX_FIXTURE_ROOT/global.json"
          fi
          cat "$FCITX_FIXTURE_ROOT/$target.json"
          ;;
        set)
          test "$#" -eq 2
          payload="$(cat)"
          printf '%s\t%s\n' "$target" "$payload" >> "$FCITX_FIXTURE_ROOT/post.log"
          if test "''${FCITX_FAIL_SET_ONCE:-}" = "$target" \
            && test ! -e "$FCITX_FIXTURE_ROOT/.failed-set-before-$target"; then
            touch "$FCITX_FIXTURE_ROOT/.failed-set-before-$target"
            if test "''${FCITX_INJECT_THIRD_VALUE:-0}" = 1; then
              jq '
                (.Children[] | select(.Option == "Behavior")
                  | .Children[] | select(.Option == "ShareInputState") | .Value)
                  = "Program"
              ' "$FCITX_FIXTURE_ROOT/global.json" > "$FCITX_FIXTURE_ROOT/global.next"
              mv "$FCITX_FIXTURE_ROOT/global.next" "$FCITX_FIXTURE_ROOT/global.json"
            fi
            echo "fixture: injected one-shot set failure for $target" >&2
            exit 1
          fi
          if test "''${FCITX_FAIL_ROLLBACK_TARGET:-}" = "$target"; then
            case "$target" in
              global)
                if test "$(jq -r '.Behavior.ShareInputState' <<< "$payload")" = No; then
                  echo "fixture: injected rollback failure for $target" >&2
                  exit 1
                fi
                ;;
            esac
          fi
          fail_after_apply=0
          if test "''${FCITX_FAIL_AFTER_APPLY_ONCE:-}" = "$target" \
            && test ! -e "$FCITX_FIXTURE_ROOT/.failed-set-after-$target"; then
            touch "$FCITX_FIXTURE_ROOT/.failed-set-after-$target"
            fail_after_apply=1
          fi
          case "$target" in
            global)
              jq --argjson patch "$payload" '
                (.Children[] | select(.Option == "Behavior")
                  | .Children[] | select(.Option == "ShareInputState") | .Value)
                  = $patch.Behavior.ShareInputState
              ' "$FCITX_FIXTURE_ROOT/global.json" > "$FCITX_FIXTURE_ROOT/global.next"
              mv "$FCITX_FIXTURE_ROOT/global.next" "$FCITX_FIXTURE_ROOT/global.json"
              ;;
            macosfrontend)
              jq --argjson patch "$payload" '
                (.Children[] | select(.Option == "AppDefaultIM") | .Value)
                  = (if $patch.AppDefaultIM == {} then "" else $patch.AppDefaultIM end)
              ' "$FCITX_FIXTURE_ROOT/macosfrontend.json" > "$FCITX_FIXTURE_ROOT/macosfrontend.next"
              mv "$FCITX_FIXTURE_ROOT/macosfrontend.next" "$FCITX_FIXTURE_ROOT/macosfrontend.json"
              ;;
            *)
              echo "fixture: unsupported set target: $target" >&2
              exit 1
              ;;
          esac
          if test "$fail_after_apply" -eq 1; then
            echo "fixture: injected post-apply failure for $target" >&2
            exit 1
          fi
          ;;
        *)
          echo "fixture: unsupported verb: $verb" >&2
          exit 64
          ;;
      esac
    '';
  };

  reconciler =
    import ../../modules/home/capabilities/macos-chinese-input/fcitx5-behavior-reconciler.nix
      {
        inherit
          contract
          lib
          pkgs
          ;
        configAdapter = fakeAdapter;
      };
in
pkgs.runCommand "macbook-fcitx5-behavior-adapter"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.jq
      productionAdapter
      reconciler
    ];
  }
  ''
    set -euo pipefail

    prepare_fixture() {
      local root="$1"
      local global="$2"
      local frontend="$3"
      local rime="$4"
      mkdir -p "$root"
      cp "$global" "$root/global.json"
      cp "$frontend" "$root/macosfrontend.json"
      cp "$rime" "$root/rime.json"
    }

    expect_preflight_failure() {
      local label="$1"
      local fixture_root="$2"
      local journal_root="$3"
      export FCITX_FIXTURE_ROOT="$fixture_root"
      if ${lib.getExe reconciler} reconcile "$journal_root"; then
        echo "fixture: expected preflight failure: $label" >&2
        exit 1
      fi
      test ! -e "$fixture_root/post.log"
      test -d "$journal_root"
      test ! -e "$journal_root/last-change.json"
      test ! -e "$journal_root/.lock"
    }

    expect_adapter_rejection() {
      local target="$1"
      local payload="$2"
      local calls_before calls_after
      calls_before="$(wc -l < "$FCITX_CLIENT_LOG" | tr -d ' ')"
      if printf '%s' "$payload" | ${lib.getExe productionAdapter} set "$target"; then
        echo "fixture: production adapter accepted forbidden payload for $target: $payload" >&2
        exit 1
      fi
      calls_after="$(wc -l < "$FCITX_CLIENT_LOG" | tr -d ' ')"
      test "$calls_after" = "$calls_before"
    }

    # Production adapter validates its exact partial-update allowlist before I/O.
    export FCITX_CLIENT_LOG="$TMPDIR/production-client.log"
    touch "$FCITX_CLIENT_LOG"
    printf '%s' '{"Behavior":{"ShareInputState":"All"}}' | ${lib.getExe productionAdapter} set global
    printf '%s' '{"AppDefaultIM":{"0":"{\"appId\":\"com.apple.Terminal\",\"appPath\":\"/System/Applications/Utilities/Terminal.app\",\"imName\":\"keyboard-us\"}"}}' \
      | ${lib.getExe productionAdapter} set macosfrontend
    test "$(wc -l < "$FCITX_CLIENT_LOG" | tr -d ' ')" = 2
    expect_adapter_rejection global '{"Behavior":{"ShareInputState":"All"},"Extra":true}'
    expect_adapter_rejection global '{"Behavior":{"ShareInputState":"All","Extra":true}}'
    expect_adapter_rejection global '{"Behavior":{"ShareInputState":"Invalid"}}'
    expect_adapter_rejection macosfrontend '{"AppDefaultIM":{},"Extra":true}'
    expect_adapter_rejection macosfrontend '{"AppDefaultIM":{"0":"not-json"}}'
    expect_adapter_rejection macosfrontend '{"AppDefaultIM":{"0":"{\"appId\":\"com.apple.Terminal\",\"appPath\":1,\"imName\":\"keyboard-us\"}"}}'
    expect_adapter_rejection macosfrontend '{"AppDefaultIM":{"0":"{\"appId\":\"com.apple.Terminal\",\"appPath\":\"/System/Applications/Utilities/Terminal.app\",\"extra\":true,\"imName\":\"keyboard-us\"}"}}'

    # Approved owned drift is reconciled without changing Keep or unowned values.
    export FCITX_FIXTURE_ROOT="$TMPDIR/approved-drift"
    journal_root="$TMPDIR/approved-drift-journal"
    prepare_fixture "$FCITX_FIXTURE_ROOT" ${initialGlobal} ${initialFrontend} ${initialRime}

    vim_mode_before="$(jq -c '.Children[] | select(.Option == "VimMode") | .Value' "$FCITX_FIXTURE_ROOT/macosfrontend.json")"

    ${lib.getExe reconciler} reconcile "$journal_root"

    test "$(jq -r '.Children[] | select(.Option == "Behavior") | .Children[] | select(.Option == "ShareInputState") | .Value' "$FCITX_FIXTURE_ROOT/global.json")" = All
    test "$(jq -r '.Children[] | select(.Option == "AppDefaultIM") | .Value' "$FCITX_FIXTURE_ROOT/macosfrontend.json")" = ""
    test "$(jq -c '.Children[] | select(.Option == "Hotkey") | .Children[] | select(.Option == "AltTriggerKeys") | .Value' "$FCITX_FIXTURE_ROOT/global.json")" = '{"0":"Shift+Shift_L","1":"Shift+Shift_R"}'
    test "$(jq -r '.Children[] | select(.Option == "StatusBar") | .Value' "$FCITX_FIXTURE_ROOT/macosfrontend.json")" = Hidden
    test "$(jq -c '.Children[] | select(.Option == "VimMode") | .Value' "$FCITX_FIXTURE_ROOT/macosfrontend.json")" = "$vim_mode_before"
    test "$(wc -l < "$FCITX_FIXTURE_ROOT/post.log" | tr -d ' ')" = 2
    test -f "$journal_root/last-change.json"
    test "$(stat -c '%a' "$journal_root")" = 700
    test "$(stat -c '%a' "$journal_root/last-change.json")" = 600
    jq -e '
      .version == 2
      and (.transaction | type == "string" and length > 0)
      and .status == "committed"
      and (.changes | length == 2)
      and (.changes[0] == {
        target: "global",
        path: "Behavior.ShareInputState",
        before: "No",
        after: "All",
        applied: true
      })
      and (.changes[1] == {
        target: "macosfrontend",
        path: "AppDefaultIM",
        before: {
          "0": "{\"appId\":\"com.apple.Terminal\",\"appPath\":\"/System/Applications/Utilities/Terminal.app\",\"imName\":\"keyboard-us\"}"
        },
        after: {},
        applied: true
      })
    ' "$journal_root/last-change.json" >/dev/null

    # A correct reconcile preserves an existing committed journal byte-for-byte.
    committed_hash="$(sha256sum "$journal_root/last-change.json" | cut -d ' ' -f1)"
    ${lib.getExe reconciler} reconcile "$journal_root"
    test "$(wc -l < "$FCITX_FIXTURE_ROOT/post.log" | tr -d ' ')" = 2
    test "$(sha256sum "$journal_root/last-change.json" | cut -d ' ' -f1)" = "$committed_hash"

    # Explicit rollback restores a committed transaction in reverse order.
    ${lib.getExe reconciler} rollback "$journal_root"
    test "$(jq -r '.Children[] | select(.Option == "Behavior") | .Children[] | select(.Option == "ShareInputState") | .Value' "$FCITX_FIXTURE_ROOT/global.json")" = No
    test "$(jq -c '.Children[] | select(.Option == "AppDefaultIM") | .Value' "$FCITX_FIXTURE_ROOT/macosfrontend.json")" = "$(jq -c '.Children[] | select(.Option == "AppDefaultIM") | .Value' ${initialFrontend})"
    test "$(cut -f1 "$FCITX_FIXTURE_ROOT/post.log" | paste -sd, -)" = global,macosfrontend,macosfrontend,global
    test "$(jq -r '.status' "$journal_root/last-change.json")" = rolled-back
    test ! -e "$journal_root/.lock"

    # A repeated rollback is rejected; later drift archives rolled-back evidence.
    rolled_back_hash="$(sha256sum "$journal_root/last-change.json" | cut -d ' ' -f1)"
    rolled_back_transaction="$(jq -r '.transaction' "$journal_root/last-change.json")"
    rolled_back_archive="$journal_root/last-change.$rolled_back_transaction.rolled-back.json"
    if ${lib.getExe reconciler} rollback "$journal_root"; then
      echo "fixture: repeated rollback must be rejected" >&2
      exit 1
    fi
    ${lib.getExe reconciler} reconcile "$journal_root"
    test "$(wc -l < "$FCITX_FIXTURE_ROOT/post.log" | tr -d ' ')" = 6
    test -f "$rolled_back_archive"
    test "$(stat -c '%a' "$rolled_back_archive")" = 600
    test "$(sha256sum "$rolled_back_archive" | cut -d ' ' -f1)" = "$rolled_back_hash"
    test "$(jq -r '.status' "$journal_root/last-change.json")" = committed

    # Correct state is a strict no-op for both public verbs.
    export FCITX_FIXTURE_ROOT="$TMPDIR/already-correct"
    no_op_journal="$TMPDIR/already-correct-journal"
    prepare_fixture "$FCITX_FIXTURE_ROOT" ${desiredGlobal} ${desiredFrontend} ${initialRime}
    ${lib.getExe reconciler} check
    ${lib.getExe reconciler} reconcile "$no_op_journal"
    test ! -e "$FCITX_FIXTURE_ROOT/post.log"
    test -d "$no_op_journal"
    test "$(stat -c '%a' "$no_op_journal")" = 700
    test ! -e "$no_op_journal/last-change.json"
    test ! -e "$no_op_journal/.lock"

    # New drift archives a committed journal and starts a fresh transaction.
    export FCITX_FIXTURE_ROOT="$TMPDIR/committed-redrift"
    committed_redrift_journal="$TMPDIR/committed-redrift-journal"
    prepare_fixture "$FCITX_FIXTURE_ROOT" ${initialGlobal} ${initialFrontend} ${initialRime}
    ${lib.getExe reconciler} reconcile "$committed_redrift_journal"
    first_committed_hash="$(sha256sum "$committed_redrift_journal/last-change.json" | cut -d ' ' -f1)"
    first_committed_transaction="$(jq -r '.transaction' "$committed_redrift_journal/last-change.json")"
    first_committed_archive="$committed_redrift_journal/last-change.$first_committed_transaction.committed.json"
    cp ${initialGlobal} "$FCITX_FIXTURE_ROOT/global.json"
    ${lib.getExe reconciler} reconcile "$committed_redrift_journal"
    test "$(wc -l < "$FCITX_FIXTURE_ROOT/post.log" | tr -d ' ')" = 3
    test -f "$first_committed_archive"
    test "$(stat -c '%a' "$first_committed_archive")" = 600
    test "$(sha256sum "$first_committed_archive" | cut -d ' ' -f1)" = "$first_committed_hash"
    test "$(jq -r '.status' "$committed_redrift_journal/last-change.json")" = committed
    test "$(jq -r '.changes | length' "$committed_redrift_journal/last-change.json")" = 1

    # Keep drift fails before either a journal or a POST can be created.
    keep_drift_root="$TMPDIR/keep-drift"
    prepare_fixture "$keep_drift_root" ${keepDriftGlobal} ${initialFrontend} ${initialRime}
    expect_preflight_failure keep-drift "$keep_drift_root" "$TMPDIR/keep-drift-journal"

    # Duplicate/malformed owned and Keep fields fail closed before mutation.
    duplicate_owned_root="$TMPDIR/duplicate-owned"
    prepare_fixture "$duplicate_owned_root" ${duplicateOwnedGlobal} ${initialFrontend} ${initialRime}
    expect_preflight_failure duplicate-owned "$duplicate_owned_root" "$TMPDIR/duplicate-owned-journal"

    malformed_owned_root="$TMPDIR/malformed-owned"
    prepare_fixture "$malformed_owned_root" ${initialGlobal} ${malformedOwnedFrontend} ${initialRime}
    expect_preflight_failure malformed-owned "$malformed_owned_root" "$TMPDIR/malformed-owned-journal"

    malformed_entry_root="$TMPDIR/malformed-entry"
    prepare_fixture "$malformed_entry_root" ${initialGlobal} ${malformedEntryFrontend} ${initialRime}
    expect_preflight_failure malformed-entry "$malformed_entry_root" "$TMPDIR/malformed-entry-journal"

    duplicate_keep_root="$TMPDIR/duplicate-keep"
    prepare_fixture "$duplicate_keep_root" ${initialGlobal} ${duplicateKeepFrontend} ${initialRime}
    expect_preflight_failure duplicate-keep "$duplicate_keep_root" "$TMPDIR/duplicate-keep-journal"

    malformed_keep_root="$TMPDIR/malformed-keep"
    prepare_fixture "$malformed_keep_root" ${initialGlobal} ${initialFrontend} ${malformedKeepRime}
    expect_preflight_failure malformed-keep "$malformed_keep_root" "$TMPDIR/malformed-keep-journal"

    # Probe failure cannot create a journal or reach a config mutation.
    export FCITX_FIXTURE_ROOT="$TMPDIR/probe-failure"
    probe_journal="$TMPDIR/probe-failure-journal"
    prepare_fixture "$FCITX_FIXTURE_ROOT" ${initialGlobal} ${initialFrontend} ${initialRime}
    if FCITX_FAIL_PROBE=1 ${lib.getExe reconciler} reconcile "$probe_journal"; then
      echo "fixture: expected probe failure" >&2
      exit 1
    fi
    test ! -e "$FCITX_FIXTURE_ROOT/post.log"
    test -d "$probe_journal"
    test ! -e "$probe_journal/last-change.json"
    test ! -e "$probe_journal/.lock"

    # A failed second POST that did not apply is not redundantly restored.
    export FCITX_FIXTURE_ROOT="$TMPDIR/second-post-failure"
    rollback_journal="$TMPDIR/second-post-failure-journal"
    prepare_fixture "$FCITX_FIXTURE_ROOT" ${initialGlobal} ${initialFrontend} ${initialRime}
    app_default_before="$(jq -c '.Children[] | select(.Option == "AppDefaultIM") | .Value' "$FCITX_FIXTURE_ROOT/macosfrontend.json")"
    if FCITX_FAIL_SET_ONCE=macosfrontend ${lib.getExe reconciler} reconcile "$rollback_journal"; then
      echo "fixture: expected second POST failure" >&2
      exit 1
    fi
    test "$(jq -r '.Children[] | select(.Option == "Behavior") | .Children[] | select(.Option == "ShareInputState") | .Value' "$FCITX_FIXTURE_ROOT/global.json")" = No
    test "$(jq -c '.Children[] | select(.Option == "AppDefaultIM") | .Value' "$FCITX_FIXTURE_ROOT/macosfrontend.json")" = "$app_default_before"
    test "$(cut -f1 "$FCITX_FIXTURE_ROOT/post.log" | paste -sd, -)" = global,macosfrontend,global
    test -f "$rollback_journal/last-change.json"
    test "$(jq -r '.status' "$rollback_journal/last-change.json")" = rolled-back
    test "$(jq -c '[.changes[].applied]' "$rollback_journal/last-change.json")" = '[true,false]'

    # A POST that applies and then errors is detected by CAS and restored.
    export FCITX_FIXTURE_ROOT="$TMPDIR/after-applied-failure"
    after_applied_journal="$TMPDIR/after-applied-failure-journal"
    prepare_fixture "$FCITX_FIXTURE_ROOT" ${initialGlobal} ${initialFrontend} ${initialRime}
    if FCITX_FAIL_AFTER_APPLY_ONCE=macosfrontend ${lib.getExe reconciler} reconcile "$after_applied_journal"; then
      echo "fixture: expected after-applied POST failure" >&2
      exit 1
    fi
    test "$(jq -r '.Children[] | select(.Option == "Behavior") | .Children[] | select(.Option == "ShareInputState") | .Value' "$FCITX_FIXTURE_ROOT/global.json")" = No
    test "$(jq -c '.Children[] | select(.Option == "AppDefaultIM") | .Value' "$FCITX_FIXTURE_ROOT/macosfrontend.json")" = "$app_default_before"
    test "$(cut -f1 "$FCITX_FIXTURE_ROOT/post.log" | paste -sd, -)" = global,macosfrontend,macosfrontend,global
    test "$(jq -r '.status' "$after_applied_journal/last-change.json")" = rolled-back
    test "$(jq -c '[.changes[].applied]' "$after_applied_journal/last-change.json")" = '[true,true]'

    # A legal third value introduced after per-item verification cannot be committed.
    export FCITX_FIXTURE_ROOT="$TMPDIR/final-read-drift"
    final_read_journal="$TMPDIR/final-read-drift-journal"
    prepare_fixture "$FCITX_FIXTURE_ROOT" ${initialGlobal} ${initialFrontend} ${initialRime}
    if FCITX_DRIFT_GLOBAL_ON_GET=4 ${lib.getExe reconciler} reconcile "$final_read_journal"; then
      echo "fixture: final-read owned drift must prevent commit" >&2
      exit 1
    fi
    test "$(jq -r '.Children[] | select(.Option == "Behavior") | .Children[] | select(.Option == "ShareInputState") | .Value' "$FCITX_FIXTURE_ROOT/global.json")" = Program
    test "$(jq -c '.Children[] | select(.Option == "AppDefaultIM") | .Value' "$FCITX_FIXTURE_ROOT/macosfrontend.json")" = "$app_default_before"
    test "$(cut -f1 "$FCITX_FIXTURE_ROOT/post.log" | paste -sd, -)" = global,macosfrontend,macosfrontend
    test "$(jq -r '.status' "$final_read_journal/last-change.json")" = rollback-incomplete

    # A third value is never overwritten by rollback CAS.
    export FCITX_FIXTURE_ROOT="$TMPDIR/third-value"
    third_value_journal="$TMPDIR/third-value-journal"
    prepare_fixture "$FCITX_FIXTURE_ROOT" ${initialGlobal} ${initialFrontend} ${initialRime}
    if FCITX_FAIL_SET_ONCE=macosfrontend FCITX_INJECT_THIRD_VALUE=1 \
      ${lib.getExe reconciler} reconcile "$third_value_journal"; then
      echo "fixture: expected third-value rollback failure" >&2
      exit 1
    fi
    test "$(jq -r '.Children[] | select(.Option == "Behavior") | .Children[] | select(.Option == "ShareInputState") | .Value' "$FCITX_FIXTURE_ROOT/global.json")" = Program
    test "$(cut -f1 "$FCITX_FIXTURE_ROOT/post.log" | paste -sd, -)" = global,macosfrontend
    test "$(jq -r '.status' "$third_value_journal/last-change.json")" = rollback-incomplete
    incomplete_hash="$(sha256sum "$third_value_journal/last-change.json" | cut -d ' ' -f1)"
    if ${lib.getExe reconciler} reconcile "$third_value_journal"; then
      echo "fixture: incomplete journal must block a new reconcile" >&2
      exit 1
    fi
    test "$(wc -l < "$FCITX_FIXTURE_ROOT/post.log" | tr -d ' ')" = 2
    test "$(sha256sum "$third_value_journal/last-change.json" | cut -d ' ' -f1)" = "$incomplete_hash"

    # A rollback adapter failure preserves the after value and records incomplete status.
    export FCITX_FIXTURE_ROOT="$TMPDIR/rollback-failure"
    rollback_failure_journal="$TMPDIR/rollback-failure-journal"
    prepare_fixture "$FCITX_FIXTURE_ROOT" ${initialGlobal} ${initialFrontend} ${initialRime}
    if FCITX_FAIL_SET_ONCE=macosfrontend FCITX_FAIL_ROLLBACK_TARGET=global \
      ${lib.getExe reconciler} reconcile "$rollback_failure_journal"; then
      echo "fixture: expected rollback adapter failure" >&2
      exit 1
    fi
    test "$(jq -r '.Children[] | select(.Option == "Behavior") | .Children[] | select(.Option == "ShareInputState") | .Value' "$FCITX_FIXTURE_ROOT/global.json")" = All
    test "$(jq -r '.status' "$rollback_failure_journal/last-change.json")" = rollback-incomplete
    ${lib.getExe reconciler} rollback "$rollback_failure_journal"
    test "$(jq -r '.Children[] | select(.Option == "Behavior") | .Children[] | select(.Option == "ShareInputState") | .Value' "$FCITX_FIXTURE_ROOT/global.json")" = No
    test "$(jq -c '.Children[] | select(.Option == "AppDefaultIM") | .Value' "$FCITX_FIXTURE_ROOT/macosfrontend.json")" = "$app_default_before"
    test "$(cut -f1 "$FCITX_FIXTURE_ROOT/post.log" | paste -sd, -)" = global,macosfrontend,global,global
    test "$(jq -r '.status' "$rollback_failure_journal/last-change.json")" = rolled-back

    # Unapplied journal entries may only be observed at their before value.
    export FCITX_FIXTURE_ROOT="$TMPDIR/unapplied-journal-item"
    unapplied_journal="$TMPDIR/unapplied-journal-item-journal"
    prepare_fixture "$FCITX_FIXTURE_ROOT" ${initialGlobal} ${desiredFrontend} ${initialRime}
    mkdir -m 0700 "$unapplied_journal"
    unapplied_before="$(jq -c '.Children[] | select(.Option == "AppDefaultIM") | .Value' ${initialFrontend})"
    jq -cn \
      --argjson before "$unapplied_before" \
      '{
        version: 2,
        transaction: "20260811T010203Z-4242",
        status: "rollback-incomplete",
        changes: [{
          target: "macosfrontend",
          path: "AppDefaultIM",
          before: $before,
          after: {},
          applied: false
        }]
      }' > "$unapplied_journal/last-change.json"
    chmod 0600 "$unapplied_journal/last-change.json"
    if ${lib.getExe reconciler} rollback "$unapplied_journal"; then
      echo "fixture: unapplied after value must fail closed" >&2
      exit 1
    fi
    test ! -e "$FCITX_FIXTURE_ROOT/post.log"
    test "$(jq -r '.status' "$unapplied_journal/last-change.json")" = rollback-incomplete
    cp -f ${initialFrontend} "$FCITX_FIXTURE_ROOT/macosfrontend.json"
    ${lib.getExe reconciler} rollback "$unapplied_journal"
    test ! -e "$FCITX_FIXTURE_ROOT/post.log"
    test "$(jq -r '.status' "$unapplied_journal/last-change.json")" = rolled-back

    # Explicit rollback preflights every CAS and performs zero config writes on a third value.
    export FCITX_FIXTURE_ROOT="$TMPDIR/explicit-third-value"
    explicit_third_journal="$TMPDIR/explicit-third-value-journal"
    prepare_fixture "$FCITX_FIXTURE_ROOT" ${initialGlobal} ${initialFrontend} ${initialRime}
    ${lib.getExe reconciler} reconcile "$explicit_third_journal"
    jq '
      (.Children[] | select(.Option == "Behavior")
        | .Children[] | select(.Option == "ShareInputState") | .Value)
        = "Program"
    ' "$FCITX_FIXTURE_ROOT/global.json" > "$FCITX_FIXTURE_ROOT/global.next"
    mv "$FCITX_FIXTURE_ROOT/global.next" "$FCITX_FIXTURE_ROOT/global.json"
    if ${lib.getExe reconciler} rollback "$explicit_third_journal"; then
      echo "fixture: explicit rollback must reject a third value" >&2
      exit 1
    fi
    test "$(wc -l < "$FCITX_FIXTURE_ROOT/post.log" | tr -d ' ')" = 2
    test "$(jq -r '.Children[] | select(.Option == "Behavior") | .Children[] | select(.Option == "ShareInputState") | .Value' "$FCITX_FIXTURE_ROOT/global.json")" = Program
    test "$(jq -r '.Children[] | select(.Option == "AppDefaultIM") | .Value' "$FCITX_FIXTURE_ROOT/macosfrontend.json")" = ""
    test "$(jq -r '.status' "$explicit_third_journal/last-change.json")" = rollback-incomplete
    if ${lib.getExe reconciler} rollback "$explicit_third_journal"; then
      echo "fixture: retry must still reject the third value" >&2
      exit 1
    fi
    test "$(wc -l < "$FCITX_FIXTURE_ROOT/post.log" | tr -d ' ')" = 2
    test "$(jq -r '.status' "$explicit_third_journal/last-change.json")" = rollback-incomplete

    # An existing owner-only lock excludes a second reconcile before GET or mutation.
    export FCITX_FIXTURE_ROOT="$TMPDIR/lock-contention"
    lock_journal="$TMPDIR/lock-contention-journal"
    prepare_fixture "$FCITX_FIXTURE_ROOT" ${initialGlobal} ${initialFrontend} ${initialRime}
    mkdir -m 700 "$lock_journal"
    mkdir -m 700 "$lock_journal/.lock"
    if ${lib.getExe reconciler} reconcile "$lock_journal"; then
      echo "fixture: expected lock contention" >&2
      exit 1
    fi
    test ! -e "$FCITX_FIXTURE_ROOT/post.log"
    test ! -e "$lock_journal/last-change.json"

    # Journal roots with unsafe mode or symlink identity fail before adapter I/O.
    export FCITX_FIXTURE_ROOT="$TMPDIR/unsafe-journal-root"
    unsafe_mode_journal="$TMPDIR/unsafe-mode-journal"
    prepare_fixture "$FCITX_FIXTURE_ROOT" ${initialGlobal} ${initialFrontend} ${initialRime}
    mkdir -m 0755 "$unsafe_mode_journal"
    if ${lib.getExe reconciler} reconcile "$unsafe_mode_journal"; then
      echo "fixture: unsafe journal mode must fail closed" >&2
      exit 1
    fi
    test ! -e "$FCITX_FIXTURE_ROOT/post.log"

    export FCITX_FIXTURE_ROOT="$TMPDIR/symlink-journal-root"
    symlink_target="$TMPDIR/symlink-journal-target"
    symlink_journal="$TMPDIR/symlink-journal"
    prepare_fixture "$FCITX_FIXTURE_ROOT" ${initialGlobal} ${initialFrontend} ${initialRime}
    mkdir -m 0700 "$symlink_target"
    ln -s "$symlink_target" "$symlink_journal"
    if ${lib.getExe reconciler} reconcile "$symlink_journal"; then
      echo "fixture: symlink journal root must fail closed" >&2
      exit 1
    fi
    test ! -e "$FCITX_FIXTURE_ROOT/post.log"

    touch "$out"
  ''
