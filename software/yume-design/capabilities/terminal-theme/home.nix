{
  inputs,
  lib,
  ...
}:

let
  terminalTheme = builtins.fromJSON (
    builtins.readFile "${inputs.yume-design}/terminal/obsidian-theme/theme.json"
  );
  inherit (terminalTheme) terminal tokens;

  isHex = value: builtins.isString value && builtins.match "^#[0-9A-Fa-f]{6}$" value != null;
  colors =
    terminal.ansi
    ++ terminal.brights
    ++ [
      terminal.background
      terminal.foreground
      terminal.cursor
      terminal.cursorText
      terminal.selectionBackground
      terminal.selectionForeground
    ]
    ++ builtins.attrValues tokens.text
    ++ builtins.attrValues tokens.intent
    ++ builtins.attrValues tokens.bg;
in
{
  _module.args.terminalTheme = terminalTheme;

  assertions = [
    {
      assertion =
        lib.all (name: builtins.hasAttr name terminalTheme) [
          "schemaVersion"
          "id"
          "name"
          "appearance"
          "terminal"
          "tokens"
        ]
        && lib.all (name: builtins.hasAttr name terminal) [
          "background"
          "foreground"
          "cursor"
          "cursorText"
          "selectionBackground"
          "selectionForeground"
          "ansi"
          "brights"
        ]
        && lib.all (name: builtins.hasAttr name tokens) [
          "text"
          "intent"
          "bg"
        ]
        && lib.all (name: builtins.hasAttr name tokens.text) [
          "primary"
          "muted"
          "subtle"
          "faint"
        ]
        && lib.all (name: builtins.hasAttr name tokens.intent) [
          "success"
          "danger"
          "warning"
          "info"
          "structure"
          "accent"
        ]
        && lib.all (name: builtins.hasAttr name tokens.bg) [
          "surface"
          "highlight"
          "selection"
        ];
      message = "The yume-design terminal theme must provide every field required by the runtime adapters.";
    }
    {
      assertion = terminalTheme.schemaVersion == 1;
      message = "The yume-design terminal theme must use schema version 1.";
    }
    {
      assertion = terminalTheme.id == "sayoriqwq-obsidian" && terminalTheme.appearance == "dark";
      message = "The terminal theme provider expects the dark sayoriqwq-obsidian design contract.";
    }
    {
      assertion = builtins.length terminal.ansi == 8 && builtins.length terminal.brights == 8;
      message = "The terminal theme must define exactly eight ANSI and eight bright colors.";
    }
    {
      assertion = lib.all isHex colors;
      message = "Every terminal color and semantic token must be a six-digit HEX value.";
    }
    {
      assertion =
        terminal.foreground == tokens.text.primary
        && terminal.background == terminal.cursorText
        && terminal.background == builtins.elemAt terminal.ansi 0
        && terminal.selectionForeground == tokens.text.primary
        && terminal.selectionBackground == tokens.bg.selection;
      message = "The terminal foreground, background, cursor text, and selection mappings must match their semantic tokens.";
    }
    {
      assertion =
        terminal.ansi == [
          terminal.background
          tokens.intent.danger
          tokens.intent.success
          tokens.intent.warning
          tokens.intent.info
          tokens.intent.accent
          tokens.intent.structure
          tokens.text.muted
        ];
      message = "ANSI slots 0-7 must preserve the yume-design semantic mapping.";
    }
    {
      assertion =
        builtins.elemAt terminal.brights 0 == tokens.text.faint
        && builtins.elemAt terminal.brights 7 == "#FFFFFF"
        && builtins.elemAt terminal.ansi 3 == "#D4A373"
        && builtins.elemAt terminal.brights 3 == "#E6C280";
      message = "Bright black/white and the approved ANSI yellow slots must preserve the design contract.";
    }
  ];
}
