{ lib, ... }:

{
  # zoxide itself initializes at order 851. Install the wrapper afterwards,
  # but before zsh-syntax-highlighting, which must remain last.
  programs.zsh.initContent = lib.mkOrder 1200 ''
    function __sayori_cd_notice() {
      print -P "%F{8}zoxide -> %F{12}$1%f"
    }

    function __sayori_cd_multi_notice() {
      print -P "%F{8}zoxide: 匹配到 $1 个目录，进入选择%f"
    }

    function __sayori_cd() {
      local -a query_argv matches
      query_argv=("$@")

      if (( $# == 0 )); then
        __zoxide_z
        return $?
      fi

      if [[ "$1" == "-" && $# == 1 ]]; then
        __zoxide_z -
        return $?
      fi

      if (( $# == 1 )) && [[ -d "$1" ]]; then
        __zoxide_z "$1"
        return $?
      fi

      if (( $# == 2 )) && [[ "$1" == "--" ]]; then
        if [[ -d "$2" ]]; then
          __zoxide_z -- "$2"
          return $?
        fi
        query_argv=("$2")
      fi

      matches=("''${(@f)$(command zoxide query --exclude "$PWD" --list -- "''${query_argv[@]}" 2>/dev/null)}")

      if (( ''${#matches[@]} == 0 )); then
        __zoxide_z "$@"
        return $?
      fi

      if (( ''${#matches[@]} == 1 )); then
        __sayori_cd_notice "$matches[1]"
        builtin cd -- "$matches[1]"
        return $?
      fi

      __sayori_cd_multi_notice "''${#matches[@]}"
      local result
      result="$(command zoxide query --exclude "$PWD" --interactive -- "''${query_argv[@]}")" &&
        builtin cd -- "$result"
    }

    function cd() {
      __sayori_cd "$@"
    }
  '';
}
