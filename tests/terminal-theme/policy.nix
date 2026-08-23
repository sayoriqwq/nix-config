{
  inputs,
  lib,
  macbookConfiguration,
  nixboxConfiguration,
  pkgs,
  serverConfiguration,
  source,
  username,
}:

let
  revision = "047c1f44518ed353b8f5d821fc1f3f347ded9206";
  theme = builtins.fromJSON (
    builtins.readFile "${inputs.yume-design}/terminal/obsidian-theme/theme.json"
  );
  inherit (theme) terminal tokens;

  macbook = macbookConfiguration.config.home-manager.users.${username};
  nixbox = nixboxConfiguration.config.home-manager.users.${username};
  server = serverConfiguration.config.home-manager.users.${username};
  homes = [
    macbook
    nixbox
    server
  ];

  palette = lib.imap0 (index: value: "${toString index}=${value}") (
    terminal.ansi ++ terminal.brights
  );
  colorScheme = {
    inherit (terminal)
      ansi
      brights
      background
      foreground
      ;
    cursor_bg = terminal.cursor;
    cursor_border = terminal.cursor;
    cursor_fg = terminal.cursorText;
    selection_bg = terminal.selectionBackground;
    selection_fg = terminal.selectionForeground;
  };
  ghosttyTheme = {
    inherit palette;
    background = [ terminal.background ];
    foreground = [ terminal.foreground ];
    "cursor-color" = [ terminal.cursor ];
    "cursor-text" = [ terminal.cursorText ];
    "selection-background" = [ terminal.selectionBackground ];
    "selection-foreground" = [ terminal.selectionForeground ];
  };

  fishColor = value: lib.removePrefix "#" value;
  expectedFishShellInit = ''
    set --global fish_color_normal ${fishColor tokens.text.primary}
    set --global fish_color_command ${fishColor tokens.intent.success}
    set --global fish_color_error ${fishColor tokens.intent.danger}
    set --global fish_color_keyword ${fishColor tokens.intent.info}
    set --global fish_color_param ${fishColor tokens.text.primary}
    set --global fish_color_option ${fishColor tokens.text.primary}
    set --global fish_color_quote ${fishColor tokens.text.primary}
    set --global fish_color_operator ${fishColor tokens.intent.structure}
    set --global fish_color_redirection ${fishColor tokens.intent.structure} --bold
    set --global fish_color_end ${fishColor tokens.intent.structure}
    set --global fish_color_escape ${fishColor tokens.intent.info} --bold
    set --global fish_color_comment ${fishColor tokens.text.faint}
    set --global fish_color_cwd ${fishColor tokens.intent.info}
    set --global fish_color_cwd_root ${fishColor tokens.intent.danger}
    set --global fish_color_autosuggestion ${fishColor tokens.text.faint}
    set --global fish_color_history_current --bold
    set --global fish_color_host ${fishColor tokens.text.primary}
    set --global fish_color_host_remote ${fishColor tokens.intent.structure}
    set --global fish_color_cancel --reverse
    set --global fish_color_status ${fishColor tokens.intent.danger}
    set --global fish_color_user ${fishColor tokens.intent.success}
    set --global fish_color_valid_path ${fishColor tokens.text.primary} --underline
    set --global fish_color_search_match ${fishColor tokens.text.primary} --bold --background=${fishColor tokens.bg.highlight}
    set --global fish_color_selection ${fishColor tokens.text.primary} --bold --background=${fishColor tokens.bg.selection}

    set --global fish_pager_color_completion ${fishColor tokens.text.primary}
    set --global fish_pager_color_prefix ${fishColor tokens.text.primary} --bold --underline
    set --global fish_pager_color_description ${fishColor tokens.text.primary} --italics
    set --global fish_pager_color_selected_background --background=${fishColor tokens.bg.surface}
    set --global fish_pager_color_selected_completion ${fishColor tokens.text.primary}
    set --global fish_pager_color_selected_description ${fishColor tokens.text.faint}
    set --global fish_pager_color_selected_prefix ${fishColor tokens.text.primary} --bold
    set --global fish_pager_color_progress ${fishColor tokens.intent.warning} --bold --background=${fishColor tokens.bg.surface}
  '';
  fishUsesTheme = home: home.programs.fish.shellInit == expectedFishShellInit;

  starshipUsesTheme =
    home:
    let
      settings = home.programs.starship.settings;
    in
    settings.directory.style == tokens.intent.info
    && settings.directory.before_repo_root_style == tokens.text.subtle
    && settings.directory.repo_root_style == tokens.intent.info
    && settings.directory.read_only_style == tokens.intent.danger
    && settings.character.success_symbol == "[❯](${tokens.intent.accent})"
    && settings.character.error_symbol == "[❯](${tokens.intent.danger})"
    && settings.character.vimcmd_symbol == "[❮](${tokens.intent.success})"
    && settings.git_branch.style == tokens.intent.accent
    && settings.git_status.style == tokens.intent.structure
    && lib.hasInfix "(${tokens.intent.warning})" settings.git_status.format
    && settings.git_state.style == tokens.text.faint
    && settings.cmd_duration.style == tokens.intent.warning
    && settings.python.style == tokens.text.faint;
in
assert lib.assertMsg (
  inputs.yume-design.rev or null == revision
) "yume-design must stay pinned to the reviewed Issue #155 revision";
assert lib.assertMsg (
  builtins.elemAt terminal.ansi 3 == "#D4A373" && builtins.elemAt terminal.brights 3 == "#E6C280"
) "the locked design source must preserve the approved yellow and bright-yellow values";
assert lib.assertMsg (lib.all fishUsesTheme homes)
  "Fish on macbook, nixbox, and server must use the shared semantic theme tokens";
assert lib.assertMsg (lib.all starshipUsesTheme homes)
  "Starship on macbook, nixbox, and server must use the shared semantic theme tokens";
assert lib.assertMsg (
  macbook.programs.ghostty.themes.${theme.id} == ghosttyTheme
  && nixbox.programs.ghostty.themes.${theme.id} == ghosttyTheme
) "Ghostty on both workstations must adapt the complete locked terminal palette";
assert lib.assertMsg (
  !server.programs.ghostty.enable
) "the shared theme provider must not enable Ghostty on the server";
assert lib.assertMsg (
  macbook.programs.wezterm.colorSchemes.${theme.id} == colorScheme
) "the macOS WezTerm compatibility adapter must use the complete locked terminal palette";
assert lib.assertMsg (
  !nixbox.programs.wezterm.enable && !server.programs.wezterm.enable
) "the shared theme provider must not enable WezTerm outside the macOS compatibility capability";
pkgs.runCommand "terminal-theme-policy"
  {
    nativeBuildInputs = [ pkgs.gnugrep ];
  }
  ''
    set -euo pipefail

    old_theme=${source}/modules/home/desktop/terminal/themes/sayoriqwq-obsidian.nix
    test ! -e "$old_theme"

    for capability in \
      ${source}/modules/home/capabilities/portable-shell.nix \
      ${source}/modules/home/capabilities/terminal-toolkit.nix \
      ${source}/modules/home/capabilities/ghostty-terminal.nix \
      ${source}/modules/home/capabilities/macos-terminal-compatibility.nix
    do
      test "$(grep -F -c '../common/terminal-theme.nix' "$capability")" = 1
    done

    if grep -E '(^|[^[:alnum:]_])#?[0-9A-Fa-f]{6}([^[:alnum:]_]|$)' \
      ${source}/modules/home/common/shell/fish.nix \
      ${source}/modules/home/common/cli/starship.nix \
      ${source}/modules/home/desktop/terminal/adapters/ghostty.nix \
      ${source}/modules/home/desktop/terminal/adapters/wezterm.nix
    then
      printf 'terminal adapters must not contain copied HEX values\n' >&2
      exit 1
    fi

    if grep -R -E -q '/(Users|home)/[^[:space:]/]+(/[^[:space:]/]+)*/yume-design' ${source}; then
      printf 'nix-config must not depend on a machine-local yume-design path\n' >&2
      exit 1
    fi

    theme_path='/terminal/obsidian-theme/theme.json'
    theme_consumers="${source}/modules/home/common/terminal-theme.nix ${source}/tests/terminal-theme/policy.nix"
    theme_reads="$(grep -F -h "$theme_path" $theme_consumers | grep -F 'builtins.readFile')"
    test "$(printf '%s\n' "$theme_reads" | wc -l | tr -d ' ')" = 2
    if printf '%s\n' "$theme_reads" | grep -F -v 'inputs.yume-design'; then
      printf 'terminal theme reads must use only inputs.yume-design\n' >&2
      exit 1
    fi

    touch "$out"
  ''
