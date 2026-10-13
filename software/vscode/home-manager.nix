{
  config,
  lib,
  pkgs,
  ...
}:

let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  baseline = pkgs.writeText "vscode-settings.jsonc" (builtins.readFile ./settings.jsonc);
  target = "${config.home.homeDirectory}/Library/Application Support/Code/User/settings.json";
in
{
  home.packages = lib.optionals (!isDarwin) [ pkgs.vscode ];

  # The native macOS bundle owns updates; CLI calls use that same installation.
  home.file.".local/bin/code" = lib.mkIf isDarwin {
    source = config.lib.file.mkOutOfStoreSymlink "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code";
  };

  # 每次应用整份基线，生成普通可写文件；未入仓的现场设置不保留。
  home.activation.applyVscodeSettings = lib.mkIf isDarwin (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${pkgs.coreutils}/bin/install -D -T -m 0644 -- ${baseline} ${lib.escapeShellArg target}
    ''
  );
}
