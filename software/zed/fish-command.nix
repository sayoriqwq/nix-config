{
  # zoxide uses `--cmd cd`, so this quick command remains unambiguous.
  programs.fish.functions.z = ''
    if test (count $argv) -eq 0
        command zed .
    else
        command zed $argv
    end
  '';
}
