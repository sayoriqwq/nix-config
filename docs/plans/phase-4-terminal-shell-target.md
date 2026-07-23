# Phase 4 终端与 Shell 最终目标基线

本文固化 Issue [#23](https://github.com/sayoriqwq/nix-config/issues/23) 在架构 grilling 与紧急修复完成后的最终共识。它取代该 Issue 早期关于 Homebrew、Darwin-only Zsh、编辑器 launcher 与 mise 退出的结论。

本文只描述声明式终态，不授权 activation、Homebrew 卸载、数据删除或合并 Pull Request。

## 1. 支持环境

- 主环境：Ghostty + Fish。
- 兼容环境：WezTerm + Zsh。
- Ghostty + Zsh 与 WezTerm + Fish 不属于承诺维护和验收的组合。
- Ghostty 是终端视觉与默认键位基准；WezTerm 只适配双方能自然对应的高频语义。
- Zsh 是跨 macOS、Linux 与 NixOS 的可移植 Shell，不属于 Darwin 私有配置。

## 2. 软件与配置所有权

| 能力 | 安装所有者 | 稳定配置所有者 | 可变状态 |
| --- | --- | --- | --- |
| Ghostty | Home Manager/Nix；Darwin 使用 `ghostty-bin`，Linux 使用 `ghostty` | `modules/home/desktop/terminal/` | 窗口、session、登录态与 macOS preferences 保持可写 |
| WezTerm | Home Manager/Nixpkgs | `modules/home/desktop/terminal/` | 窗口、mux 与运行时状态保持可写 |
| Fish/Zsh | Home Manager；macOS 登录 Fish 由 nix-darwin 声明 | `modules/home/common/shell/` | history 与 universal variables 保持可写 |
| Node/Bun/pnpm | mise | Nix 管理 mise 本体、默认值和 Shell integration | mise runtime/cache/state 保持可写 |
| Maple Mono NF-CN | macOS 由 nix-darwin 安装 | `modules/darwin/fonts.nix` | 无用户数据 |

Ghostty 与 WezTerm 的应用本体不再由 Homebrew 声明。`homebrew.onActivation.cleanup` 继续为 `none`；真实机器先验证 Nix 应用，再经当次批准定向卸载两个 cask。

两个终端都关闭自身更新检查，版本升级只通过 `flake.lock` 与 Nix 完成：

- Ghostty：`auto-update = off`；
- WezTerm：`check_for_updates = false`。

## 3. 模块结构

```text
modules/home/
├── common/
│   ├── default.nix
│   ├── shell/
│   └── cli/
├── desktop/
│   ├── default.nix
│   └── terminal/
│       ├── default.nix
│       ├── appearance.nix
│       ├── keybindings.nix
│       ├── themes/
│       └── adapters/
└── darwin/
    ├── default.nix
    ├── cli/
    └── integrations/
```

- 目录通过 `default.nix` 暴露，不使用 `index.nix`。
- 不保留 `common.nix + common/` 等同名文件与目录。
- Shell 模块只拥有 Shell 原生行为；第三方软件的包、配置与 hook 由对应 CLI 模块拥有。
- 简单能力使用单文件；存在多个稳定子域或 Shell adapter 时才使用目录。
- 能力由实际配置效果表达，不建立通用 capability 数据库。
- 快捷键只提供生成 `docs/guide/SHORTCUTS.md` 所需的最小元数据。
- Ghostty 原生 `Ctrl+Cmd+=` 保留为均分所有 pane；WezTerm 没有对应原生动作，不引入脆弱的自定义 pane-tree 算法。

## 4. 终端主题与行为

`sayoriqwq-obsidian.nix` 是 Ghostty/WezTerm 的唯一主题数据源，Ghostty 当前值为权威：

- ANSI yellow：`#BDBDBD`，有意设计为中性灰；
- bright yellow：`#FFFFFF`；
- Maple Mono NF-CN，字号 `20`；
- 背景透明度 `0.95`；
- 背景模糊 `10`。

Ghostty 保持自身窗口与原生 tabs；WezTerm 可以保留适合其实现的窗口外壳。两者不追求像素级组件一致。

Ghostty 使用默认 `shell-integration = detect` 自动集成初始 Fish；Home Manager 不重复注入 Fish/Zsh。WezTerm 由 Home Manager 为 Zsh 加载上游 shell integration。Ghostty 默认关闭的 `sudo`/`ssh` 包装不启用。

## 5. Shell 与 CLI 行为

- Atuin：Fish/Zsh 共用数据库；`Ctrl+R` 是唯一增强历史入口，不绑定 `Ctrl+Up`。
- Fish/Zsh：上下方向键保留前缀历史行为。
- fzf：保留 `Ctrl+T` 与 `Alt+C`，显式不占用 `Ctrl+R`。
- zoxide：Fish/Zsh 提供等价的增强 `cd`。
- eza：提供 `ls`、`ll`、`la`、`lla`、`lt`，图标为自动模式。
- lazygit：`lg` 启动；正常退出同步目录，`Shift+Q` 不同步。
- direnv/nix-direnv：两个 Shell 都启用 hook；项目仍需 `.envrc` 与显式 `direnv allow`。
- pay-respects：由 Nix 管理，Fish/Zsh 使用上游别名 `f`；不保留 `thefuck`/`fuck`。
- mise：Fish/Zsh 都启用；Node、Bun、pnpm 默认 `latest`，Nix 不直接安装这些 runtime。
- Starship：Fish/Zsh 使用同一提示符配置。

`v`、`z` 与 VS Code/Zed 的应用、配置和 launcher 全部移出 #23，留给编辑器迁移阶段共同设计。

## 6. 删除与保留边界

#23 从声明中删除：

- OpenClaw Shell integration；
- 通用 `/opt/homebrew/bin` PATH；
- `~/Library/pnpm` PATH；
- Cargo/rustup、GHCup、Cabal PATH 与初始化；
- Homebrew thefuck compatibility；
- Atuin `Ctrl+Up`；
- Ghostty/WezTerm Homebrew cask 声明。

#23 不删除真实数据目录，也不迁移以下能力：

- `~/.cargo`、`~/.rustup`、`~/.ghcup`、`~/.cabal`；
- Atuin、Fish、Zsh、mise、Ghostty、WezTerm 的可变数据；
- OrbStack 软件与容器数据；
- Homebrew PostgreSQL 16 service 与数据目录；
- VS Code、Zed 或其配置。

OrbStack 与 PostgreSQL 分别使用独立迁移 Issue。#23 仅隔离并保留当前必要的 Darwin integration。

## 7. 验收与人工关卡

Agent 必须完成：

```fish
nix fmt -- --check .
nix flake check
nix build .#darwinConfigurations.macbook.system --no-link
```

还需验证：

- Home Manager closure 包含 Nix Ghostty、WezTerm、Fish、Zsh、mise、pnpm 默认声明与 Maple Mono NF-CN；
- 生成的 Ghostty/WezTerm 配置能由对应 CLI 解析；
- Fish/Zsh 语法通过；
- Atuin 与 fzf 的最终键位没有 `Ctrl+R` 冲突；
- `v`、`z`、OpenClaw、thefuck、Rust/Haskell/pnpm 旧 PATH 不出现在生成配置；
- dotfiles handoff 后 chezmoi 不再管理 WezTerm/Zsh 目标；
- 可变 history、数据库与状态目录没有被链接进 Nix Store。

真实机器 activation、登录 Shell 切换、Homebrew 定向卸载与任何数据删除均是独立人工关卡。回滚优先切回上一代 nix-darwin/Home Manager generation；Homebrew app 需要按 activation 前清单单独恢复。
