{ config, lib, ... }:

let
  inherit (lib)
    concatMapStringsSep
    mkOption
    replaceStrings
    sort
    types
    ;

  escapeCell = value: replaceStrings [ "|" "\n" ] [ "\\|" " " ] value;
  renderRow =
    shortcut:
    "| ${escapeCell shortcut.scope} | `${escapeCell shortcut.keys}` | ${escapeCell shortcut.action} | ${escapeCell shortcut.owner} |";

  reference = ''
    # 快捷键与快速入口

    > 本表由各能力模块声明的行为元数据生成，并在 Nix 求值时检查漂移。配置事实仍归对应模块所有。

    | 范围 | 快捷键或入口 | 行为 | 所有者 |
    | --- | --- | --- | --- |
    ${concatMapStringsSep "\n" renderRow (
      sort (left: right: left.order < right.order) config.sayori.shortcuts
    )}

    `Cmd+Backquote` 未被 nix-config 绑定；Ghostty Quick Terminal 不在当前支持范围内。
  '';
in
{
  options.sayori = {
    shortcuts = mkOption {
      type = types.listOf (
        types.submodule {
          options = {
            scope = mkOption {
              type = types.str;
              description = "User-facing shortcut scope.";
            };
            keys = mkOption {
              type = types.str;
              description = "Key chord or quick command.";
            };
            action = mkOption {
              type = types.str;
              description = "User-visible behavior.";
            };
            owner = mkOption {
              type = types.str;
              description = "Capability module that owns the behavior.";
            };
            order = mkOption {
              type = types.int;
              description = "Stable display order in the generated guide.";
            };
          };
        }
      );
      default = [ ];
      internal = true;
      description = "Minimal metadata used to render the shortcut guide.";
    };

    shortcutReference = mkOption {
      type = types.lines;
      readOnly = true;
      internal = true;
      description = "Rendered shortcut reference used by the drift check.";
    };
  };

  config = {
    sayori.shortcutReference = reference;

    assertions = [
      {
        assertion = reference == builtins.readFile ../../../docs/guide/SHORTCUTS.md;
        message = ''
          docs/guide/SHORTCUTS.md is out of sync with the shortcut metadata
          declared by Home Manager capability modules.
        '';
      }
    ];
  };
}
