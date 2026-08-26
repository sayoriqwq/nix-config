{
  config,
  lib,
  ...
}:

let
  inherit (lib) concatMapStringsSep replaceStrings sort;

  escapeCell = value: replaceStrings [ "|" "\n" ] [ "\\|" " " ] value;
  renderRow =
    shortcut:
    "| ${escapeCell shortcut.scope} | `${escapeCell shortcut.keys}` | ${escapeCell shortcut.action} | ${escapeCell shortcut.owner} |";

  reference = ''
    # 快捷键与快速入口

    > 本表由当前 Host 最终选择的 Software 声明生成。配置事实仍归对应 Software 所有。

    | 范围 | 快捷键或入口 | 行为 | 所有者 |
    | --- | --- | --- | --- |
    ${concatMapStringsSep "\n" renderRow (
      sort (left: right: left.order < right.order) config.sayori.shortcuts
    )}
  '';
in
{
  imports = [ ../common/shortcut-reference.nix ];

  xdg.dataFile."nix-config/SHORTCUTS.md".text = reference;
}
