{ lib, terminalTheme, ... }:

let
  inherit (terminalTheme.tokens) intent text;
in
{
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = lib.mkDefault false;

    settings = {
      format = "$username$hostname$directory$git_branch$git_state$git_status$cmd_duration$line_break$python$character";

      directory = {
        truncation_length = 3;
        truncation_symbol = "…/";
        truncate_to_repo = false;
        style = intent.info;
        before_repo_root_style = text.subtle;
        repo_root_style = intent.info;
        format = "[$read_only]($read_only_style)[$before_root_path]($before_repo_root_style)[$repo_root]($repo_root_style)[$path]($style) ";
        read_only = " 🔒";
        read_only_style = intent.danger;
      };

      character = {
        success_symbol = "[❯](${intent.accent})";
        error_symbol = "[❯](${intent.danger})";
        vimcmd_symbol = "[❮](${intent.success})";
      };

      git_branch = {
        format = "[$branch]($style)";
        style = intent.accent;
      };

      git_status = {
        format = "[[(*$conflicted$untracked$modified$staged$renamed$deleted)](${intent.warning}) ($ahead_behind$stashed)]($style)";
        style = intent.structure;
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
        style = text.faint;
      };

      cmd_duration = {
        format = "[$duration]($style) ";
        style = intent.warning;
      };

      python = {
        format = "[$virtualenv]($style) ";
        style = text.faint;
        detect_extensions = [ ];
        detect_files = [ ];
      };
    };
  };
}
