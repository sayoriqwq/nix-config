{ lib, terminalTheme, ... }:

let
  color = value: lib.removePrefix "#" value;
  inherit (terminalTheme.tokens) bg intent text;
in
{
  programs.fish = {
    enable = true;

    functions.fish_greeting = "";

    shellInit = ''
      set --global fish_color_normal ${color text.primary}
      set --global fish_color_command ${color intent.success}
      set --global fish_color_error ${color intent.danger}
      set --global fish_color_keyword ${color intent.info}
      set --global fish_color_param ${color text.primary}
      set --global fish_color_option ${color text.primary}
      set --global fish_color_quote ${color text.primary}
      set --global fish_color_operator ${color intent.structure}
      set --global fish_color_redirection ${color intent.structure} --bold
      set --global fish_color_end ${color intent.structure}
      set --global fish_color_escape ${color intent.info} --bold
      set --global fish_color_comment ${color text.faint}
      set --global fish_color_cwd ${color intent.info}
      set --global fish_color_cwd_root ${color intent.danger}
      set --global fish_color_autosuggestion ${color text.faint}
      set --global fish_color_history_current --bold
      set --global fish_color_host ${color text.primary}
      set --global fish_color_host_remote ${color intent.structure}
      set --global fish_color_cancel --reverse
      set --global fish_color_status ${color intent.danger}
      set --global fish_color_user ${color intent.success}
      set --global fish_color_valid_path ${color text.primary} --underline
      set --global fish_color_search_match ${color text.primary} --bold --background=${color bg.highlight}
      set --global fish_color_selection ${color text.primary} --bold --background=${color bg.selection}

      set --global fish_pager_color_completion ${color text.primary}
      set --global fish_pager_color_prefix ${color text.primary} --bold --underline
      set --global fish_pager_color_description ${color text.primary} --italics
      set --global fish_pager_color_selected_background --background=${color bg.surface}
      set --global fish_pager_color_selected_completion ${color text.primary}
      set --global fish_pager_color_selected_description ${color text.faint}
      set --global fish_pager_color_selected_prefix ${color text.primary} --bold
      set --global fish_pager_color_progress ${color intent.warning} --bold --background=${color bg.surface}
    '';
  };
}
