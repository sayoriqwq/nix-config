{
  imports = [
    ./shortcut-reference.nix
    ./shell
    ./cli
  ];

  home.file.".hushlogin".text = "";
}
