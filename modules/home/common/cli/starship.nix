{
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = true;

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
}
