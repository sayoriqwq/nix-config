{
  config,
  inputs,
  pkgs,
  ...
}:

{
  imports = [ ../../../../modules/home/common/state-paths.nix ];

  home.packages = [ inputs.ax.packages.${pkgs.stdenv.hostPlatform.system}.ax ];

  sayori.statePaths = [
    {
      path = "${config.home.homeDirectory}/.cache/ax/fetch";
      owner = "ax";
      backup = "excluded";
      description = "Short-lived fetched-page cache owned by ax; upstream ax keeps this cache owner-only and expires entries after roughly two minutes. Home Manager only declares the boundary and never manages cache contents or credentials.";
    }
  ];
}
