{
  inputs,
  pkgs,
  ...
}:

{
  home.packages = [ inputs.ax.packages.${pkgs.stdenv.hostPlatform.system}.ax ];
}
