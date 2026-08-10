{ lib }:

let
  behavior = {
    desired = {
      global.Behavior.ShareInputState = "All";
      macosfrontend.AppDefaultIM = { };
    };
    keep = {
      global.Hotkey.AltTriggerKeys = {
        "0" = "Shift+Shift_L";
        "1" = "Shift+Shift_R";
      };
      macosfrontend.StatusBar = "Hidden";
      rime.InputState = "All";
    };
    journal.relativePath = ".local/state/nix-config/macos-chinese-input/fcitx5-behavior";
  };
  managedPaths = [
    "LICENSE"
    "cn_dicts/41448.dict.yaml"
    "cn_dicts/8105.dict.yaml"
    "cn_dicts/base.dict.yaml"
    "cn_dicts/ext.dict.yaml"
    "cn_dicts/others.dict.yaml"
    "cn_dicts/tencent.dict.yaml"
    "custom_phrase.txt"
    "default.yaml"
    "double_pinyin.schema.yaml"
    "double_pinyin_abc.schema.yaml"
    "double_pinyin_flypy.schema.yaml"
    "double_pinyin_mspy.schema.yaml"
    "double_pinyin_sogou.schema.yaml"
    "double_pinyin_ziguang.schema.yaml"
    "en_dicts/cn_en.txt"
    "en_dicts/cn_en_abc.txt"
    "en_dicts/cn_en_double_pinyin.txt"
    "en_dicts/cn_en_flypy.txt"
    "en_dicts/cn_en_mspy.txt"
    "en_dicts/cn_en_sogou.txt"
    "en_dicts/cn_en_ziguang.txt"
    "en_dicts/en.dict.yaml"
    "en_dicts/en_ext.dict.yaml"
    "lua/autocap_filter.lua"
    "lua/calc_translator.lua"
    "lua/cn_en_spacer.lua"
    "lua/cold_word_drop/drop_words.lua"
    "lua/cold_word_drop/filter.lua"
    "lua/cold_word_drop/hide_words.lua"
    "lua/cold_word_drop/logger.lua"
    "lua/cold_word_drop/metatable.lua"
    "lua/cold_word_drop/processor.lua"
    "lua/cold_word_drop/reduce_freq_words.lua"
    "lua/cold_word_drop/string.lua"
    "lua/corrector.lua"
    "lua/date_translator.lua"
    "lua/debuger.lua"
    "lua/en_spacer.lua"
    "lua/force_gc.lua"
    "lua/is_in_user_dict.lua"
    "lua/long_word_filter.lua"
    "lua/lunar.lua"
    "lua/number_translator.lua"
    "lua/pin_cand_filter.lua"
    "lua/reduce_english_filter.lua"
    "lua/search.lua"
    "lua/select_character.lua"
    "lua/t9_preedit.lua"
    "lua/unicode.lua"
    "lua/v_filter.lua"
    "melt_eng.dict.yaml"
    "melt_eng.schema.yaml"
    "opencc/emoji.json"
    "opencc/emoji.txt"
    "opencc/others.txt"
    "radical_pinyin.dict.yaml"
    "radical_pinyin.schema.yaml"
    "rime_ice.dict.yaml"
    "rime_ice.schema.yaml"
    "squirrel.yaml"
    "symbols_caps_v.yaml"
    "symbols_v.yaml"
    "t9.schema.yaml"
    "weasel.yaml"
  ];

  forbiddenBasenames = [
    ".DS_Store"
    "installation.yaml"
    "squirrel.custom.yaml"
    "user.yaml"
  ];
  forbiddenTrees = [
    "build"
    "sync"
  ];

  pathComponents = path: lib.splitString "/" path;
  isSafeRelativePath =
    path:
    path != ""
    && !(lib.hasPrefix "/" path)
    && lib.all (component: component != "" && component != "." && component != "..") (
      pathComponents path
    );
  isForbiddenManagedPath =
    path:
    let
      components = pathComponents path;
    in
    lib.any (component: builtins.elem component forbiddenBasenames) components
    || lib.any (component: lib.hasSuffix ".userdb" component) components
    || lib.any (tree: path == tree || lib.hasPrefix "${tree}/" path) forbiddenTrees;
in
{
  inputName = "rime-ice";
  inputOwner = "iDvel";
  inputRepo = "rime-ice";
  release = "2025.04.06";
  revision = "a5f5404e369100fcfc5562f86f1205827453e31c";
  narHash = "sha256-s3r8cdEliiPnKWs64Wgi0rC9Ngl1mkIrLnr2tIcyXWw=";

  targetRoot = ".local/share/fcitx5/rime";
  expectedManagedPathCount = 65;
  localOverlay = {
    relativePath = "default.custom.yaml";
    source = ./default.custom.yaml;
    sha256 = "6d68d560d1d46937ee5e9ac10b50498257d5e868aeb2be293581a00c73aa0a30";
  };

  inherit behavior;

  inherit
    forbiddenBasenames
    forbiddenTrees
    isForbiddenManagedPath
    isSafeRelativePath
    managedPaths
    ;

  mutableStatePaths = [
    {
      relativePath = ".local/share/fcitx5/rime/build";
      owner = "Rime";
      backup = "excluded";
      description = "Rebuildable Rime deployment cache remains writable and outside the Nix store.";
    }
    {
      relativePath = ".local/share/fcitx5/rime/luna_pinyin.userdb";
      owner = "Rime";
      backup = "required";
      description = "Rime learning data remains writable; its entries must never be inspected or committed.";
    }
    {
      relativePath = ".local/share/fcitx5/rime/rime_ice.userdb";
      owner = "Rime";
      backup = "required";
      description = "Rime Ice learning data remains writable; its entries must never be inspected or committed.";
    }
    {
      relativePath = ".local/share/fcitx5/rime/sync";
      owner = "Rime";
      backup = "separate-policy";
      description = "Rime sync exports remain writable and follow their own data backup procedure.";
    }
    {
      relativePath = ".local/share/fcitx5/rime/installation.yaml";
      owner = "Rime";
      backup = "required";
      description = "Rime installation identity remains mutable and is not a static declaration.";
    }
    {
      relativePath = ".local/share/fcitx5/rime/user.yaml";
      owner = "Rime";
      backup = "required";
      description = "Rime deployment and recent-schema state remains mutable.";
    }
    {
      relativePath = ".config/fcitx5";
      owner = "Fcitx5";
      backup = "required";
      description = "Fcitx5 owns the writable mixed-state tree and all unapproved fields; nix-config reconciles only two approved semantic behavior values through the official API.";
    }
    {
      relativePath = behavior.journal.relativePath;
      owner = "nix-config macOS Chinese input behavior adapter";
      backup = "required";
      description = "Owner-only semantic rollback journal; generation rollback does not automatically restore it.";
    }
    {
      relativePath = "Library/fcitx5";
      owner = "Fcitx5 macOS installer/updater";
      backup = "separate-policy";
      description = "Fcitx5 plugin payload, shared resources, and plugin-manager state remain externally owned.";
    }
    {
      relativePath = "Library/Caches/org.fcitx.inputmethod.Fcitx5";
      owner = "Fcitx5";
      backup = "excluded";
      description = "Rebuildable Fcitx5 macOS cache remains writable and outside the Nix store.";
    }
  ];
}
