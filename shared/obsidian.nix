# Obsidian：终端配色、命令行着色与提示符共用的完整主题。
{
  id = "obsidian";
  terminal = {
    background = "#121212";
    foreground = "#E0E0E0";
    cursor = "#5FAFFF";
    cursorText = "#121212";
    selectionBackground = "#2C3E50";
    selectionForeground = "#E0E0E0";
    ansi = [
      "#121212"
      "#CF6679"
      "#81C784"
      "#D4A373"
      "#64B5F6"
      "#A291B5"
      "#76C1E1"
      "#D0D0D0"
    ];
    brights = [
      "#454545"
      "#FF8A80"
      "#B9F6CA"
      "#E6C280"
      "#82B1FF"
      "#C1B1D1"
      "#99D6EA"
      "#FFFFFF"
    ];
  };
  tokens = {
    text = {
      primary = "#E0E0E0";
      muted = "#D0D0D0";
      subtle = "#BDBDBD";
      faint = "#454545";
    };
    intent = {
      success = "#81C784";
      danger = "#CF6679";
      warning = "#D4A373";
      info = "#64B5F6";
      structure = "#76C1E1";
      accent = "#A291B5";
    };
    bg = {
      surface = "#1E1E1E";
      highlight = "#252525";
      selection = "#2C3E50";
    };
  };
}
