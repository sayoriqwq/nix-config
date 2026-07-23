{
  config,
  lib,
  pkgs,
  ...
}:

{
  home = {
    packages = with pkgs; [
      fd
      gh
      jq
      ripgrep
      tree
    ];

    # Keep user-installed portable commands available without putting a
    # platform-specific path in the shared module.
    sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];
  };

  # Nix owns mise itself and its stable defaults. The writable
  # ~/.config/mise/config.toml remains available for `mise use -g`, while
  # projects own their committed mise.toml version selections.
  xdg.configFile."mise/conf.d/10-nix-defaults.toml".text = ''
    [tools]
    bun = "latest"
    node = "latest"
  '';

  programs = {
    atuin = {
      enable = true;
      enableFishIntegration = true;
      flags = [ "--disable-up-arrow" ];
    };

    bat.enable = true;
    btop.enable = true;

    direnv = {
      enable = true;
      enableFishIntegration = true;
      nix-direnv.enable = true;
    };

    eza = {
      enable = true;
      enableFishIntegration = true;
      icons = "auto";
    };

    fish = {
      enable = true;

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

        fish_greeting = "";
      };

      shellInit = ''
        set --global fish_color_normal E0E0E0
        set --global fish_color_command 81C784
        set --global fish_color_error CF6679
        set --global fish_color_keyword 64B5F6
        set --global fish_color_param E0E0E0
        set --global fish_color_option E0E0E0
        set --global fish_color_quote E0E0E0
        set --global fish_color_operator 76C1E1
        set --global fish_color_redirection 76C1E1 --bold
        set --global fish_color_end 76C1E1
        set --global fish_color_escape 64B5F6 --bold
        set --global fish_color_comment 454545
        set --global fish_color_cwd 64B5F6
        set --global fish_color_cwd_root CF6679
        set --global fish_color_autosuggestion 454545
        set --global fish_color_history_current --bold
        set --global fish_color_host E0E0E0
        set --global fish_color_host_remote 76C1E1
        set --global fish_color_cancel --reverse
        set --global fish_color_status CF6679
        set --global fish_color_user 81C784
        set --global fish_color_valid_path E0E0E0 --underline
        set --global fish_color_search_match E0E0E0 --bold --background=252525
        set --global fish_color_selection E0E0E0 --bold --background=2C3E50

        set --global fish_pager_color_completion E0E0E0
        set --global fish_pager_color_prefix E0E0E0 --bold --underline
        set --global fish_pager_color_description E0E0E0 --italics
        set --global fish_pager_color_selected_background --background=1E1E1E
        set --global fish_pager_color_selected_completion E0E0E0
        set --global fish_pager_color_selected_description 454545
        set --global fish_pager_color_selected_prefix E0E0E0 --bold
        set --global fish_pager_color_progress D4A373 --bold --background=1E1E1E
      '';

      interactiveShellInit = lib.mkAfter ''
        function cd --wraps=__zoxide_z --description 'zoxide-backed cd with fallback notice'
            __sayori_cd $argv
        end

        # Preserve Fish's default Up/Down behavior and keep Atuin on Ctrl+Up.
        bind ctrl-up _atuin_bind_up
        bind -M insert ctrl-up _atuin_bind_up

      '';
    };

    fzf = {
      enable = true;
      enableFishIntegration = true;
    };

    git = {
      enable = true;
      includes = [ { path = "~/.config/git/identity.inc"; } ];
      ignores = [ "**/.claude/settings.local.json" ];

      # Keep gh authentication in its existing private hosts file. Only the
      # credential-helper command is declared here.
      settings.credential = {
        "https://github.com".helper = [
          ""
          "${pkgs.gh}/bin/gh auth git-credential"
        ];
        "https://gist.github.com".helper = [
          ""
          "${pkgs.gh}/bin/gh auth git-credential"
        ];
      };
    };

    helix = {
      enable = true;
      settings.theme = "ayu_dark";
    };

    lazygit.enable = true;

    mise = {
      enable = true;
      enableFishIntegration = true;
    };

    nh.enable = true;

    starship = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        format = "$username$hostname$directory$git_branch$git_state$git_status$cmd_duration$line_break$python$character";

        directory = {
          truncation_length = 3;
          truncation_symbol = "…/";
          truncate_to_repo = false;
          style = "#64B5F6";
          before_repo_root_style = "#BDBDBD";
          repo_root_style = "#64B5F6";
          format = "[$read_only]($read_only_style)[$before_root_path]($before_repo_root_style)[$repo_root]($repo_root_style)[$path]($style) ";
          read_only = " 🔒";
          read_only_style = "#CF6679";
        };

        character = {
          success_symbol = "[❯](#A291B5)";
          error_symbol = "[❯](#CF6679)";
          vimcmd_symbol = "[❮](#81C784)";
        };

        git_branch = {
          format = "[$branch]($style)";
          style = "#A291B5";
        };

        git_status = {
          format = "[[(*$conflicted$untracked$modified$staged$renamed$deleted)](#D4A373) ($ahead_behind$stashed)]($style)";
          style = "#76C1E1";
          conflicted = "!";
          untracked = "?";
          modified = "*";
          staged = "+";
          renamed = "»";
          deleted = "✘";
          stashed = "≡";
        };

        git_state = {
          format = "\\([$state( $progress_current/$progress_total)]($style)\\) ";
          style = "#454545";
        };

        cmd_duration = {
          format = "[$duration]($style) ";
          style = "#D4A373";
        };

        python = {
          format = "[$virtualenv]($style) ";
          style = "#454545";
          detect_extensions = [ ];
          detect_files = [ ];
        };
      };
    };

    tmux.enable = true;

    zoxide = {
      enable = true;
      enableFishIntegration = true;
      options = [
        "--cmd"
        "cd"
      ];
    };
  };

  # The standalone Atuin installer currently prepends ~/.atuin/bin. Replacing
  # that hook makes the Home Manager package authoritative without touching
  # Atuin's writable config, databases, keys, or daemon state.
  xdg.configFile."fish/conf.d/atuin.env.fish".text = ''
    # Atuin is provided by Home Manager; mutable Atuin state remains unmanaged.
  '';
}
