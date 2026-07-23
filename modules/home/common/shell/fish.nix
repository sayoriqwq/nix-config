{
  programs.fish = {
    enable = true;

    functions.fish_greeting = "";

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
  };
}
