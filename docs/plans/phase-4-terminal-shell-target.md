# Phase 4 终端与 Shell 最终目标基线

本文固化 Issue [#23](https://github.com/sayoriqwq/nix-config/issues/23) 的终端体验目标，
并按 Wave 3 的 V3 Software/Intent 边界校准当前声明结构。它取代该 Issue 早期关于
Homebrew、Darwin-only Zsh、编辑器 launcher 与 mise 退出的结论。

本文只描述声明式终态，不授权 activation、Homebrew 卸载、数据删除或合并 Pull Request。

> [!NOTE]
> Issue #118 修正了历史交付中遗漏的 `v`/`z` launcher；当前 `v` 由 VS Code Software
> owner 在 macbook 提供，`z` 由 Zed owner 在 macbook 与 nixbox 提供。Wave 3 的 #199
> 负责 Ghostty、WezTerm 与 Zsh；#197/PR #223 与 #198/PR #224 已合并，因此本文描述的是
> 三票集成后的当前 owner 与 caller，而不是 frozen-base 分支上的临时结构。

## 1. 支持环境与选择关系

- 主环境：Ghostty + Fish；macbook 与 nixbox 直接选择 Ghostty Software Capability。
- 兼容环境：WezTerm + Zsh；只有 macbook 通过 `intents/terminal-compatibility/default.nix`
  显式组合这两个 Software Capabilities。
- Ghostty + Zsh 与 WezTerm + Fish 不属于承诺维护和验收的组合。
- Ghostty 是终端视觉与默认键位基准；WezTerm 只适配双方能自然对应的高频语义。
- Zsh capability 使用 Home Manager 实现，但当前 host selection 只有 macbook；不能从实现层
  可移植性推断 nixbox 或 server 需求。
- 三台 host 继续通过 `intents/terminal-work/default.nix` 选择共享终端工具与
  `yume-design` terminal-theme provider。

## 2. 软件与配置所有权

| 能力 | 安装与稳定配置唯一 owner | 组合方式 | 可变状态 |
| --- | --- | --- | --- |
| Ghostty | `software/ghostty/capabilities/terminal-emulator/home.nix` | macbook、nixbox 直接选择 | 窗口、session、登录态与 macOS preferences 保持可写 |
| WezTerm | `software/wezterm/capabilities/terminal-emulator/home.nix` | macbook 的 `terminal-compatibility` Intent | 窗口、mux 与运行时状态保持可写 |
| Fish | 用户配置：`software/fish/capabilities/interactive-shell/home.nix`（#197/PR #223 已合并）；Darwin 注册：`modules/darwin/shell.nix`；NixOS 登录 Shell：`modules/capabilities/portable-shell/nixos.nix` | 三台 host 显式选择用户 owner，并按平台选择 system declaration；Fish 不拥有 Zsh 行为 | Fish history 与 universal variables 保持可写 |
| Zsh | `software/zsh/capabilities/compatibility-shell/home.nix` | macbook 的 `terminal-compatibility` Intent；不拥有其他 Software 的 integration 原子 | `~/.zhistory` 保持可写 |
| 终端主题 | `software/yume-design/capabilities/terminal-theme/home.nix` | `terminal-work` 选择；Ghostty/WezTerm owner 消费同一 `terminalTheme` interface | 无可变状态 |
| Node/Bun/pnpm | mise owner | 项目版本继续由项目 `mise.toml` 或本机未提交 override 选择 | mise runtime、cache、state 保持可写 |
| Maple Mono NF-CN | macOS：`modules/darwin/fonts.nix`；Linux Ghostty：Ghostty owner | host 按真实终端需求选择 | 无用户数据；headless server 不安装字体 |

Ghostty 与 WezTerm 的应用本体不由 Homebrew 声明。`homebrew.onActivation.cleanup` 保持
`none`；任何真实机器安装来源切换或定向卸载都需要独立人工批准。

两个终端都关闭自身更新检查，版本升级只通过 `flake.lock` 与 Nix 完成：

- Ghostty：`auto-update = off`；
- WezTerm：`check_for_updates = false`。

## 3. 当前 V3 结构

```text
intents/
├── terminal-work/
│   └── default.nix
└── terminal-compatibility/
    ├── default.nix
    └── zsh-integrations.nix       # 已批准的临时跨 Software seam

software/
├── fish/
│   └── capabilities/interactive-shell/home.nix   # #197 / PR #223 已合并
├── ghostty/
│   └── capabilities/terminal-emulator/home.nix
├── wezterm/
│   ├── default.nix
│   └── capabilities/terminal-emulator/home.nix
├── yume-design/
│   ├── default.nix
│   └── capabilities/terminal-theme/home.nix
└── zsh/
    ├── default.nix
    └── capabilities/compatibility-shell/home.nix

modules/
├── capabilities/portable-shell/
│   └── nixos.nix                  # NixOS Fish 登录 Shell declaration
├── darwin/
│   └── shell.nix                  # macOS Fish 注册；人工 chsh 另设 Gate
└── home/
    ├── common/
    │   ├── shortcut-reference.nix # 共享 option primitive
    │   └── state-paths.nix        # 共享 option primitive
    ├── darwin/
    │   └── hushlogin.nix          # Zsh owner 使用的 Darwin primitive
    └── desktop/terminal/
        ├── appearance.nix         # 终端 owner 使用的共享值 primitive
        └── keybindings.nix        # Ghostty/WezTerm 使用的共享键位 primitive
```

- `software/*/capabilities/` 是 package、稳定配置与状态边界的唯一 owner；Host 只选择
  Capability 或 realized Intent，不重新拥有实现。
- `software/*/default.nix` 只为确实由 Intent 组合的 Software 暴露窄 transform；Ghostty
  由 host 直接选择，因此不为目录外观创建空 interface。
- `modules/home/desktop/terminal/{appearance,keybindings}.nix` 仍是被明确路径 import 的内部
  primitives，不是可选择 adapter、第二 owner 或 terminal bundle。
- `modules/darwin/shell.nix` 与 `modules/capabilities/portable-shell/nixos.nix` 只拥有各自平台的
  Fish system declaration；它们不拥有 Fish 用户配置，更不拥有 Zsh。
- 已退役的 `modules/home/desktop/terminal/adapters/` 与 `modules/home/common/shell/zsh.nix`
  不再是当前接口；不得恢复旧 `default.nix` 聚合树、registry 或自动扫描。
- 快捷键只提供生成 `docs/guide/SHORTCUTS.md` 所需的最小元数据。
- Ghostty 原生 `Ctrl+Cmd+=` 保留为均分所有 pane；WezTerm 没有对应原生动作，不引入
  脆弱的自定义 pane-tree 算法。

## 4. 终端主题与行为

锁定的 `yume-design/terminal/obsidian-theme/theme.json` 是颜色、ANSI palette、语义 Token
与 appearance 的唯一设计源。`software/yume-design/capabilities/terminal-theme/home.nix`
读取并校验 JSON，通过 `terminalTheme` interface 供 Ghostty、WezTerm、Fish 与 Starship
消费；各 Software owner 不保存 HEX 副本。

`modules/home/desktop/terminal/appearance.nix` 只保留字号、透明度与模糊等共享值，
`keybindings.nix` 只保留两个终端真实共享的按键映射；两者都不安装 package、不声明状态，
也不能由 host 单独选择。

Issue #155 接受的主题裁决保持不变：

- ANSI yellow：`#D4A373`，映射 `tokens.intent.warning`；
- bright yellow：`#E6C280`，保留 warning 语义与 ANSI 槽位辨识度；
- Maple Mono NF-CN，字号 `20`；
- 背景透明度 `0.95`；
- 背景模糊 `10`。

Ghostty 保持自身窗口与原生 tabs；WezTerm 可以保留适合其实现的窗口外壳。两者不追求
像素级组件一致。Ghostty 使用默认 `shell-integration = detect` 集成初始 Fish，Home Manager
不重复注入 Fish/Zsh；WezTerm owner 启用自己的 Zsh integration，并以 Zsh package 作为
默认登录程序。Ghostty 默认关闭的 `sudo`/`ssh` 包装不启用。

## 5. Shell 与 CLI 行为

- Fish owner 单独声明 Fish 的上下方向键前缀历史行为；不得配置或宣称 Zsh。
- Zsh owner 单独声明 `history-search-backward` / `history-search-forward` bindkey 与 Zsh
  history；`docs/guide/SHORTCUTS.md` 分别显示 Fish 与 Zsh 的真实 owner。
- Atuin：Fish/Zsh 共用数据库；`Ctrl+R` 是唯一增强历史入口，不绑定 `Ctrl+Up`。
- fzf：保留 `Ctrl+T` 与 `Alt+C`，显式不占用 `Ctrl+R`。
- zoxide：Fish/Zsh 提供等价的增强 `cd`。
- eza：提供 `ls`、`ll`、`la`、`lla`、`lt`，图标为自动模式。
- lazygit：`lg` 启动；正常退出同步目录，`Shift+Q` 不同步。
- direnv/nix-direnv：两个 Shell 都启用 hook；项目仍需 `.envrc` 与显式 `direnv allow`。
- pay-respects：由 Nix 管理，Fish/Zsh 使用上游别名 `f`；不保留 `thefuck`/`fuck`。
- mise：Fish/Zsh 都启用；Node、Bun、pnpm 默认 `latest`，Nix 不直接安装这些 runtime。
- Starship：Fish/Zsh 使用同一提示符配置。

`intents/terminal-compatibility/zsh-integrations.nix` 当前显式组合 Atuin、direnv、eza、fzf、
LazyGit、mise、pay-respects、Starship 与 zoxide 的既有 Zsh integrations。Lead 已批准它作为
Wave 3 临时 seam；#199 不跨 #196/#197/#198 修改这些 owners，也不删除现有行为。各 owner
提供窄 contribution 后的 replacement 记录到 #206，并必须在 #202 前清偿；不得把临时 seam
移回 Zsh owner、bundle 或 registry。

在 #23 的原始范围内，`v`、`z` 与 VS Code/Zed 的应用、配置和 launcher 被移出终端阶段。
Issue #118 已修正该延期：`v` 由 VS Code owner 提供，`z` 由 Zed owner 提供。

## 6. 删除与保留边界

#23 从声明中删除 OpenClaw Shell integration、通用 `/opt/homebrew/bin` PATH、
`~/Library/pnpm` PATH、Cargo/rustup、GHCup、Cabal PATH 与初始化、Homebrew thefuck
compatibility、Atuin `Ctrl+Up`，以及 Ghostty/WezTerm Homebrew cask 声明。

Wave 3 #199 进一步删除以下旧 owner/interface：

- `modules/home/capabilities/ghostty-terminal.nix`；
- `modules/home/capabilities/macos-terminal-compatibility.nix`；
- `modules/home/common/shell/zsh.nix`；
- `modules/home/desktop/terminal/adapters/ghostty.nix`；
- `modules/home/desktop/terminal/adapters/wezterm.nix`。

`appearance.nix` 与 `keybindings.nix` 作为 owner 内部消费的共享 primitives 保留；它们不再
代表终端所有权。#199 不删除真实数据目录，也不迁移 Atuin、Fish、Zsh、mise、Ghostty、
WezTerm、OrbStack、VS Code 或 Zed 的可变数据、账号、session、history、数据库或 cache。

OrbStack 与 PostgreSQL 分别使用独立迁移 Issue。#23 当时保留的 PostgreSQL integration
已由 #60 后续删除；OrbStack 当前由自己的 Software owner 管理 package、integration 与
外部状态边界。

## 7. 验收与人工关卡

Agent 至少完成：

```fish
nix fmt -- --check .
nix flake check
nix flake check --no-build --all-systems
nix build .#darwinConfigurations.macbook.system --no-link --print-out-paths
nix eval --raw .#nixosConfigurations.nixbox.config.system.build.toplevel.drvPath
```

还需验证：

- Ghostty、WezTerm、Fish、Zsh 与 terminal theme 分别来自上述唯一 owner，旧 owner 路径无引用；
- macbook 组合 `terminal-compatibility`，nixbox 不选择 WezTerm/Zsh compatibility；
- 生成的 Ghostty/WezTerm 配置能由对应 CLI 解析，Fish/Zsh 语法通过；
- Fish 与 Zsh 的 `↑ / ↓` 分别由各自 owner 声明，Atuin 与 fzf 不争用 `Ctrl+R`；
- 当前 `v` 随 macbook 的 VS Code capability 提供，`z` 随 macbook 与 nixbox 的 Zed
  capability 提供；
- dotfiles handoff 后 chezmoi 不再管理 WezTerm/Zsh 目标；
- 可变 history、数据库与状态目录没有被链接进 Nix Store。

nixbox/x86_64-linux 原生 build 与真实运行态验证统一留给 #202；不得为此使用 SSH、远端
builder 或 activation。真实机器 activation、登录 Shell 切换、安装来源切换与任何数据删除
均是独立人工关卡。回滚优先切回上一代 nix-darwin/Home Manager generation；构建成功不构成
activation 授权。
