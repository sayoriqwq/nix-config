{ lib, ... }:

{
  programs.fish = {
    functions = {
      __sayori_cd_notice = {
        argumentNames = "target";
        body = ''
          set_color $fish_color_comment
          echo -n "zoxide -> "
          set_color $fish_color_valid_path
          echo $target
          set_color normal
        '';
      };

      __sayori_cd_multi_notice = {
        argumentNames = "count";
        body = ''
          set_color $fish_color_comment
          echo "zoxide: 匹配到 $count 个目录，进入选择"
          set_color normal
        '';
      };

      __sayori_cd = ''
        set -l argc (count $argv)
        set -l query_argv $argv

        if test $argc -eq 0
            __zoxide_z
            return $status
        end

        if test "$argv" = -
            __zoxide_z -
            return $status
        end

        if test $argc -eq 1 -a -d "$argv[1]"
            __zoxide_z $argv[1]
            return $status
        end

        if test $argc -eq 2 -a "$argv[1]" = --
            if test -d "$argv[2]"
                __zoxide_z -- $argv[2]
                return $status
            end
            set query_argv $argv[2]
        end

        set -l matches (command zoxide query --exclude (__zoxide_pwd) --list -- $query_argv 2>/dev/null)
        set -l match_count (count $matches)

        if test $match_count -eq 0
            __zoxide_z $argv
            return $status
        end

        if test $match_count -eq 1
            __sayori_cd_notice $matches[1]
            __zoxide_cd $matches[1]
            return $status
        end

        __sayori_cd_multi_notice $match_count
        set -l result (command zoxide query --exclude (__zoxide_pwd) --interactive -- $query_argv)
        and __zoxide_cd $result
      '';
    };

    interactiveShellInit = lib.mkAfter ''
      function cd --wraps=__zoxide_z --description 'zoxide-backed cd with fallback notice'
          __sayori_cd $argv
      end
    '';
  };
}
