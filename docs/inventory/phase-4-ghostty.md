# Phase 4 Ghostty 迁移记录

本文记录 Issue [#22](https://github.com/sayoriqwq/nix-config/issues/22) 的证据、所有权交接、离线验证、人工 activation 清单与回滚步骤。本文不授权 activation、Homebrew cleanup 或删除可变数据。

## 1. 迁移前证据

- 采集日期：2026-07-22。
- 当前应用：`/Applications/Ghostty.app`，Ghostty `1.3.1`，不是 Homebrew 已登记 cask。
- chezmoi source：`~/.local/share/chezmoi/dot_config/ghostty/`。
- live 配置：`~/.config/ghostty/config` 与 `~/.config/ghostty/themes/sayoriqwq-obsidian`。
- macOS 专属目录只发现空文件 `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty`，未发现第二份非空配置或主题覆盖。
- `ghostty +validate-config` 对迁移前 live 配置返回成功。

迁移前私有备份位于 `/Users/sayori/ghostty-phase4.CQpxrz`，目录权限为 `0700`，文件权限为 `0600`。备份包含 `live/` 与 `chezmoi-source/` 两套 config/themes；备份本体不进入 Git。

| 文件 | SHA-256 |
| --- | --- |
| live config | `4609c677586a7918e5b6e42872ae8cec29f6ca84c2da0d16a1dd12efed507e2e` |
| chezmoi source config | `a1211b437a87821be99442ae3caf48dc155d71ee55993a72fffa34ecf518a815` |
| live/source theme | `68c4fe49c9386e2890cce58c2c7d431dc1bf8d2bd9d9ba26f4e1571a301a4928` |

source 与 live 的主题完全一致。config 的唯一行为 drift 是 live 文件仍包含旧的 `global:cmd+backquote=toggle_quick_terminal`；chezmoi source 已删除它。Issue #22 明确要求不包含 quick-terminal，因此 Nix 目标采用已审阅的 source 状态，不保留该 live drift。

## 2. 目标所有权

| 目标 | 声明所有者 | 不接管内容 |
| --- | --- | --- |
| Ghostty macOS 应用 | nix-darwin `homebrew.casks` | 应用登录态、自动更新历史 |
| `~/.config/ghostty/config` | Home Manager `programs.ghostty.settings` | history、session、窗口恢复状态 |
| `~/.config/ghostty/themes/sayoriqwq-obsidian` | Home Manager `programs.ghostty.themes` | 其他未审阅主题 |
| 默认 shell | Phase 3 Home Manager Fish package | Homebrew Fish 或 Zsh 配置 |

Home Manager 设置 `programs.ghostty.package = null`，因此不会安装第二份 Ghostty。生成的 `command` 直接引用 `programs.fish.package` 的 Nix Store 可执行文件，不再依赖 `/opt/homebrew/bin/fish` 或未登记的 Zsh 配置。Ghostty 的 mutable state 目录不由 Home Manager 整体链接，继续保持可写并由独立备份流程负责。

## 3. chezmoi handoff

dotfiles 仓库在独立分支 `codex/phase-4-ghostty-handoff` 的提交 `2186b8e84a680abb1243dd38a826ea27e2a4faaa` 中删除两个 Ghostty source 文件，并同步更新所有权与终端文档。以该仓库为 source 运行 `chezmoi managed`，结果不再包含 Ghostty；过程中没有执行 `chezmoi apply`。

在该 handoff 合并并同步到本机 chezmoi source 之前，不得对 Ghostty 路径运行 `chezmoi apply`、`re-add` 或 `add`。

## 4. 生成配置比较与离线验证

实现完成后执行：

```bash
nix fmt -- --check .
nix flake check
nix build .#darwinConfigurations.macbook.system
```

三条命令均返回 `0`。`nix flake check` 只检查当前兼容的 Darwin output，并提示跳过不兼容的 Linux formatter；macOS system build 产物为 `/nix/store/x3ld99zkpywzqk5898cd7gww5jsvihjw-darwin-system-26.05.c3e90c8`。生成的 Brewfile 只有 `cask "ghostty", trusted: true`，`homebrew.onActivation.cleanup` 的求值结果为 `none`。

从 build 结果读取 Home Manager 生成的 config/theme，逐键与备份中的 chezmoi source 比较。预期只有两类行为差异：

1. 不生成 quick-terminal keybind；
2. `command` 从 `/opt/homebrew/bin/fish -l` 改为锁定的 Home Manager Fish Store 路径。

由于 `package = null`，Home Manager build 不会自动调用 Ghostty CLI。必须额外使用当前应用内 CLI 校验生成文件：

```bash
/Applications/Ghostty.app/Contents/MacOS/ghostty +validate-config --config-file=<generated-config>
rg 'quick[_-]terminal|toggle_quick_terminal' <generated-config> <generated-theme>
```

第二条命令预期无输出并返回 `1`。build 与 CLI 校验都不是 activation 授权。

本次 build 的生成文件结果：

| 生成文件 | SHA-256 | 校验结果 |
| --- | --- | --- |
| Ghostty config | `3b555b681061b78a48c08e65dd5028ecc3ba054a4ead1beb2a8ef2b053cef234` | Ghostty CLI 返回 `0` |
| `sayoriqwq-obsidian` theme | `2cab11a6bff77fc5743f7059a9094487847b87dac3e7a42827e5f2b0edafccfd` | Ghostty CLI 返回 `0` |

生成配置保留 source 的全部 10 个普通设置与完整 16 色 palette，并把 shell 命令解析为锁定的 Fish `4.7.1` Store 路径。对 config/theme 搜索 quick-terminal 无结果，符合预期。

## 5. 人工 activation 清单

以下步骤必须由维护者审阅两个仓库的 diff 后手动执行：

1. 合并 dotfiles handoff，并只用 Git fast-forward 同步本机 chezmoi source；不要运行全局 `chezmoi apply`。
2. 确认 `chezmoi managed | rg -i ghostty` 无输出，且私有备份 hash 仍匹配。
3. 退出 Ghostty；把现有 live config/theme 移入本次备份的 `displaced/`，避免 Home Manager 与 regular file 冲突。
4. 把当前非 Homebrew 的 `/Applications/Ghostty.app` 移入备份位置，保留原始 app bundle 作为 cask 安装失败时的回退副本。
5. 执行维护者批准的 nix-darwin activation；不得附加 Homebrew cleanup 或 zap。
6. 确认 `brew list --cask ghostty`、`/Applications/Ghostty.app` 与两个 Home Manager 配置链接均存在。
7. 运行 `ghostty +validate-config`，并在新窗口确认主题、字体、透明度、窗口样式与 Fish 登录 shell。
8. 确认 `Cmd+Backquote` 不再触发 quick terminal；确认 history、session 与登录态所在目录仍可写且不是 Nix Store 链接。

## 6. 回滚

1. 使用上一代 nix-darwin generation 回滚系统与 Home Manager 配置。
2. 若 cask 应用需要回退，先卸载本次 Ghostty cask，再从私有备份恢复原始 `Ghostty.app`；Homebrew 应用回滚不由 generation 自动完成。
3. 从 `/Users/sayori/ghostty-phase4.CQpxrz/live/` 恢复原 config/theme，并用 Ghostty CLI 校验。
4. 在 dotfiles 仓库 revert handoff 提交并用 Git fast-forward 同步本机 chezmoi source；确认所有权恢复后，才可对精确 Ghostty 目标执行 chezmoi 操作。
5. 不删除或覆盖 Ghostty history、session、登录态和其他可变数据。
