# Phase 4 终端与 Shell 最终迁移记录

本文记录 Issue [#23](https://github.com/sayoriqwq/nix-config/issues/23) 的最终所有权、验证证据、人工 activation 清单与回滚边界。本文不授权 activation、Homebrew 卸载、可变数据删除或合并 Pull Request。

## 1. 支持矩阵

| 环境 | 定位 | 应用 | Shell |
| --- | --- | --- | --- |
| Ghostty + Fish | 日常主环境 | Home Manager `programs.ghostty` | Home Manager Fish；macOS 登录 Shell 由 nix-darwin 指向同一 Nix Fish |
| WezTerm + Zsh | 长期兼容环境 | Home Manager `programs.wezterm` | Home Manager Zsh，由 WezTerm 精确引用 Nix Store executable |

Ghostty + Zsh 与 WezTerm + Fish 不属于验收矩阵。VS Code/Zed launcher 不属于本 Issue。

## 2. 迁移前证据

- Ghostty 1.3.1 已由 #22 管理配置，但应用来源仍是 Homebrew cask 声明。
- WezTerm live 配置曾由 `~/.wezterm.lua`/chezmoi 管理，应用由 Homebrew cask 安装。
- macOS 账户登录 Shell 为 `/opt/homebrew/bin/fish`。
- Zsh live 配置包含 mise、OrbStack、Cargo、GHCup、Cabal、OpenClaw 与 thefuck 等混合 integration。
- Phase 3 Fish 配置仍包含通用 Homebrew PATH、OrbStack/OpenClaw、thefuck 与 `Ctrl+Up`。
- Atuin、Fish/Zsh history、mise runtimes、终端 session 与登录态都是可变数据。

旧 WezTerm/Zsh 私有备份位置与校验和保留在 `docs/inventory/phase-4-wezterm-zsh.md`。该文档是旧交付快照，不再代表最终配置目标。

## 3. 最终所有权

| 对象 | 最终所有者 | 说明 |
| --- | --- | --- |
| Ghostty/WezTerm 软件包 | Home Manager/Nix | macOS 应用位于 `~/Applications/Home Manager Apps` |
| 终端配置、主题与共享键位 | `modules/home/desktop/terminal/` | Ghostty 为视觉与默认键位基准 |
| Fish/Zsh 原生配置 | `modules/home/common/shell/` | 可跨 Darwin/Linux/NixOS |
| CLI 软件与 Shell hook | `modules/home/common/cli/` | 每个能力拥有自己的包、配置与 integration |
| Maple Mono NF-CN | nix-darwin | `modules/darwin/fonts.nix` |
| macOS 登录 Shell | nix-darwin | Nix Fish，不再依赖 Homebrew Fish |
| Node/Bun/pnpm | mise | Nix 只安装 mise 并声明默认 `latest` |
| OrbStack hook | Darwin integration | 软件迁移与数据留给独立 Issue |
| PostgreSQL 16 PATH/service/data | 现有 Homebrew service | 本 Issue 原样保留，未来独立迁移 |

## 4. 可变数据边界

以下路径或状态不得因本次迁移被删除、覆盖或链接到只读 Nix Store：

- `~/.local/share/atuin`、Atuin key/config/daemon state；
- Fish history 与 universal variables；
- `~/.zhistory`；
- `~/.local/share/mise`、`~/.config/mise/config.toml` 与项目 `mise.toml`；
- Ghostty/WezTerm session、window、mux 与登录态；
- `~/.orbstack` 及 OrbStack container/VM/volume；
- `/opt/homebrew/var/postgresql@16`；
- `~/.cargo`、`~/.rustup`、`~/.ghcup`、`~/.cabal`。

仓库记录路径只用于说明 ownership，不代表 Git/Nix 管理其内容。

## 5. 声明式验证

2026-07-23 在 `agent/phase-4-wezterm-zsh` 的未激活工作树完成：

```fish
nix fmt -- --check .
nix flake check
nix build .#darwinConfigurations.macbook.system --no-link
```

三条命令均以状态码 0 结束。仓库当前原生 `nixfmt` 对目录参数 `.`
发出将来不再支持的弃用提示；消除该提示需要修改全仓 formatter，双轴审查
判定其超出 #23 范围，因此本 Issue 不夹带该维护改动。`nix flake check`
只检查当前 `aarch64-darwin` formatter，并按 Nix 默认行为提示跳过不兼容的
`aarch64-linux` 与 `x86_64-linux` formatter；两项提示都不是配置失败。

专项证据：

| 检查 | 结果 |
| --- | --- |
| macOS 系统输出 | `nix build .#darwinConfigurations.macbook.system --no-link` 状态码 0 |
| Home Manager generation | generation derivation 与输出均构建成功，状态码 0 |
| Ghostty | `ghostty-bin-1.3.1`；`ghostty +validate-config` 状态码 0 |
| WezTerm | `wezterm-0-unstable-2026-03-31`；`wezterm show-keys --lua` 状态码 0 |
| Shell 语法 | generation 内 Nix Fish 与 Zsh 分别通过 `fish -n`、`zsh -n` |
| Shell integration | mise 同时启用 Fish/Zsh；Ghostty 的 Home Manager Fish/Zsh integration 均关闭，由 Ghostty 原生 integration 负责 |
| runtime ownership | mise 声明 Node/Bun/pnpm `latest` 与 `activate_aggressive = true`；Home Manager profile closure 无同名 runtime 包 |
| Homebrew 终端声明 | `homebrew.casks` 求值为 `[]`；cleanup 仍为 `none` |
| Linux 复用 | `x86_64-linux` 上组合 `modules/home/common` 与 `modules/home/desktop` 求值得到 Home Manager derivation |
| dotfiles handoff | chezmoi managed 清单不再包含 `.zshrc`、`.wezterm.lua` 或对应源文件 |

生成配置还核对了共享主题、Maple Mono NF-CN 20、opacity `0.95`、
blur `10`、终端应用自动更新关闭、Atuin/FZF/pay-respects/lazygit/zoxide
的两 Shell 所有权，以及 `Ctrl+Cmd+=` 仅使用 Ghostty 原生均分行为。

Build 成功不构成 activation 授权。

## 6. 人工 activation 清单

1. 审阅 nix-config PR #27 与 dotfiles PR #3，记录待激活 commit 和当前 generation。
2. 确认 Ghostty、WezTerm、Fish、Zsh、Atuin、mise 与重要可变状态具备可用备份或可回滚来源。
3. 对待激活 Home Manager generation 的所有 `home-files` 执行 live
   regular-file 冲突扫描；本次已确认并备份
   `~/.wezterm.lua`、`~/.zshrc`、`~/.zprofile`、`~/.zshenv`、
   `~/.config/gh/config.yml` 与
   `~/Library/Application Support/lazygit/config.yml`。
4. 关闭 Ghostty 与 WezTerm，避免旧进程掩盖新配置。
5. 由维护者针对精确 commit 批准并执行 nix-darwin activation。
6. 确认账户登录 Shell 已切换到 Nix Fish，新开 Ghostty 正常进入 Fish。
7. 从 `~/Applications/Home Manager Apps` 打开 Ghostty 与 WezTerm，分别验收两套支持环境。
8. 验证快捷键、主题、字体、Atuin、fzf、zoxide、lazygit、pay-respects、direnv、mise 与 pnpm。
9. 确认 OrbStack 与 PostgreSQL 仍正常，Rust/Haskell 数据目录未删除。
10. 完成 Nix 应用验收后，再单独批准定向执行 `brew uninstall --cask ghostty wezterm`。
11. 清理后再次确认 `/Applications` 不再残留 Homebrew 终端应用，Nix 应用仍可正常启动。

## 7. 回滚

1. 切回 activation 前的 nix-darwin generation，恢复上一代 Home Manager 配置与登录 Shell 声明。
2. 若 Nix 应用不可用，在未卸载 Homebrew cask 时直接从原应用回退；已卸载时按 activation 前版本重新安装。
3. dotfiles handoff 需在其仓库单独 revert，确认所有权恢复后才允许 chezmoi 重新部署目标。
4. 不通过删除 Atuin、mise、Shell history、终端状态、OrbStack 或 PostgreSQL 数据来“修复”声明问题。
