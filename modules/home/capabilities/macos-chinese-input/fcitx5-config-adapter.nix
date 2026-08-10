{
  lib,
  pkgs,
  fcitx5Curl ? "/Library/Input Methods/Fcitx5.app/Contents/bin/fcitx5-curl",
  socketPath ? "/tmp/fcitx5.sock",
}:

pkgs.writeShellApplication {
  name = "fcitx5-config-adapter";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.jq
  ];
  text = ''
    fcitx5_curl=${lib.escapeShellArg fcitx5Curl}
    socket_path=${lib.escapeShellArg socketPath}

    usage() {
      echo "usage: fcitx5-config-adapter probe | get <global|macosfrontend|rime> | set <global|macosfrontend>" >&2
      exit 64
    }

    require_client() {
      if [[ ! -x "$fcitx5_curl" ]]; then
        echo "fcitx5-config-adapter: missing executable client: $fcitx5_curl" >&2
        exit 1
      fi
    }

    endpoint_for() {
      case "$1" in
        global) printf '%s\n' /config/global ;;
        macosfrontend) printf '%s\n' /config/addon/macosfrontend ;;
        rime) printf '%s\n' /config/addon/rime ;;
        *) return 1 ;;
      esac
    }

    request() {
      local endpoint="$1"
      shift
      "$fcitx5_curl" "$endpoint" \
        --silent \
        --show-error \
        --fail-with-body \
        --connect-timeout 2 \
        --max-time 5 \
        "$@"
    }

    validate_set_payload() {
      local target="$1"
      local payload="$2"
      case "$target" in
        global)
          jq -e '
            type == "object"
            and keys == ["Behavior"]
            and (.Behavior | type == "object")
            and (.Behavior | keys == ["ShareInputState"])
            and (
              .Behavior.ShareInputState
              | type == "string" and (. == "All" or . == "Program" or . == "No")
            )
          ' <<< "$payload" >/dev/null
          ;;
        macosfrontend)
          jq -e '
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
            and keys == ["AppDefaultIM"]
            and (.AppDefaultIM | type == "object")
            and (.AppDefaultIM | all(keys[]; test("^(0|[1-9][0-9]*)$")))
            and (.AppDefaultIM | all(.[]; valid_app_entry))
          ' <<< "$payload" >/dev/null
          ;;
        *)
          return 1
          ;;
      esac
    }

    verb="''${1:-}"
    case "$verb" in
      probe)
        [[ "$#" -eq 1 ]] || usage
        require_client
        [[ -S "$socket_path" ]] || {
          echo "fcitx5-config-adapter: expected Unix socket is unavailable: $socket_path" >&2
          exit 1
        }
        request /config/addon/beast | jq -e --arg socketPath "$socket_path" '
          type == "object"
          and (.Children | type == "array")
          and ([.Children[] | select(type == "object" and .Option? == "Communication")] | length == 1)
          and ([.Children[] | select(.Option == "Communication") | .Value][0] == "Unix Socket")
          and ([.Children[] | select(type == "object" and .Option? == "Unix Socket")] | length == 1)
          and (
            [.Children[] | select(.Option == "Unix Socket") | .Children]
            | (length == 1 and (.[0] | type == "array"))
          )
          and (
            [.Children[] | select(.Option == "Unix Socket") | .Children[]
              | select(type == "object" and .Option? == "Path")]
            | length == 1
          )
          and (
            [.Children[] | select(.Option == "Unix Socket") | .Children[]
              | select(.Option == "Path") | .Value][0] == $socketPath
          )
        ' >/dev/null
        ;;
      get)
        [[ "$#" -eq 2 ]] || usage
        require_client
        endpoint="$(endpoint_for "$2")" || usage
        request "$endpoint"
        ;;
      set)
        [[ "$#" -eq 2 ]] || usage
        case "$2" in
          global|macosfrontend) ;;
          *) usage ;;
        esac
        payload="$(cat)"
        if ! validate_set_payload "$2" "$payload"; then
          echo "fcitx5-config-adapter: rejected non-allowlisted payload for $2" >&2
          exit 1
        fi
        require_client
        endpoint="$(endpoint_for "$2")"
        response="$(printf '%s' "$payload" | request "$endpoint" \
            --request POST \
            --header 'Content-Type: application/json' \
            --data-binary @-)"
        if [[ -n "$response" ]]; then
          echo "fcitx5-config-adapter: successful POST returned a non-empty response" >&2
          exit 1
        fi
        ;;
      *)
        usage
        ;;
    esac
  '';
}
