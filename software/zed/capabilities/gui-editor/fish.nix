{
  imports = [
    ../../../../modules/home/common/shortcut-reference.nix
  ];

  # zoxide uses `--cmd cd`, so this quick command remains unambiguous.
  programs.fish.functions.z = ''
    if test (count $argv) -eq 0
        command zed .
    else
        command zed $argv
    end
  '';

  sayori.shortcuts = [
    {
      scope = "Fish / Zsh";
      keys = "z";
      action = "无参数打开当前目录；有参数传给 Zed";
      owner = "zed-editor";
      order = 46;
    }
  ];
}
