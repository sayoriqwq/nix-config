# Phase 4 终端与 Shell 最终迁移记录

本文记录 Issue [#23](https://github.com/sayoriqwq/nix-config/issues/23) 的最终所有权、验证证据、人工 activation 清单与回滚边界。本文不授权 activation、Homebrew 卸载、可变数据删除或合并 Pull Request。

## 1. 支持矩阵

| 环境 | 定位 | 应用 | Shell |
| --- | --- | --- | --- |
| Ghostty + Fish | 日常主环境 | Home Manager `programs.ghostty` | Home Manager Fish；nix-darwin 注册 Nix Fish，macOS 账户通过一次性 `chsh` 选择该稳定路径 |
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
| Nix Fish 登录路径 | nix-darwin + macOS 账户事实 | nix-darwin 注册 `/run/current-system/sw/bin/fish`；管理员账户不加入 `users.knownUsers`，由单独批准的 `chsh` 选择 |
| Node/Bun/pnpm | mise | Nix 只安装 mise 并声明默认 `latest` |
| GH CLI | Nix package-only | `config.yml` 与 `hosts.yml` 由 GH 保持本机可写，仓库只声明 Git credential helper |
| OrbStack hook | Darwin integration | 软件迁移与数据留给独立 Issue |
| PostgreSQL 16 PATH/service/data | 现有 Homebrew service | 本 Issue 原样保留，未来独立迁移 |

## 4. 可变数据边界

以下路径或状态不得因本次迁移被删除、覆盖或链接到只读 Nix Store：

- `~/.local/share/atuin`、Atuin key/config/daemon state；
- Fish history 与 universal variables；
- `~/.zhistory`；
- `~/.local/share/mise`、`~/.config/mise/config.toml` 与项目 `mise.toml`；
- `~/.config/gh/config.yml` 与 `~/.config/gh/hosts.yml`；
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

## 6. `/etc/shells` 接管诊断

维护者对 commit `2e57b14` 执行 `darwin-rebuild switch` 时，nix-darwin
在 activation 安全检查中拒绝接管 `/etc/shells`。失败后的独立 `chsh`
命令仍被执行，因此 macOS Directory Services 中的 `UserShell` 已变为
`/run/current-system/sw/bin/fish`，但 live `/etc/shells` 尚未注册该路径。

只读诊断确认：

- live `/etc/shells` 是 UID:GID `0:0`、mode `0644` 的普通文件，SHA-256 为
  `1655f96aad74ad3fd074d08a2c38fe4253ba120ed8937996f4deb89abccc2e41`；
- 文件内容是 macOS 默认 shell 清单加 `/opt/homebrew/bin/fish`；
- nix-darwin 26.05 只内置原始 macOS 文件的已知 hash
  `9d5aa72f807091b481820d12e693093293ba33c73854909ad7b0fb192c2db193`；
- 在只读管道中删除 Homebrew Fish 行后，hash 精确恢复为上述内置值，
  排除隐藏内容、权限异常或 nix-darwin hash 漂移；
- `/etc/shells.before-nix-darwin` 不存在，证明安全检查在任何接管动作前
  中止；
- 当前和待激活 generation 的稳定 Fish 路径都存在并指向可执行的
  Fish 4.7.1。本机 `chpass(1)` 只限制非 super-user 选择
  `/etc/shells` 中的 shell，`login(1)` 则直接执行账户记录的解释器，
  因此未发现当前账户立即无法登录的证据。

为避免手工移走 `/etc/shells` 后形成文件缺失窗口，`macbook` host 模块把
live 文件的精确 hash 加入 `environment.etc."shells".knownSha256Hashes`。
该主机例外只接受已审计的 212-byte 旧文件，不影响其他 Darwin 主机，也不
接受其他未知内容。activation 通过后，nix-darwin 会把旧文件保留为
`/etc/shells.before-nix-darwin`，再链接生成的 `/etc/shells`。

使用以下 Fish 命令作为 activation 前的确定性只读 preflight：

```fish
set live_hash (rtk shasum -a 256 /etc/shells | rtk cut -d " " -f 1)
set known_hashes (
  rtk nix eval --json \
    .#darwinConfigurations.macbook.config.environment.etc.shells.knownSha256Hashes \
    | rtk jq -r '.[]'
)
set live_target (rtk readlink /etc/shells 2>/dev/null)

if test "$live_target" = /etc/static/shells
  printf "GREEN already-managed target=/etc/static/shells\n"
else if contains -- $live_hash $known_hashes
  printf "GREEN recognized-live-hash=%s\n" $live_hash
else
  printf "RED unrecognized-live-hash=%s\n" $live_hash
  false
end
```

修复前针对 `2e57b14` 的生成配置运行该判定，稳定输出：

```text
RED unrecognized-live-hash=1655f96aad74ad3fd074d08a2c38fe4253ba120ed8937996f4deb89abccc2e41
```

加入精确 hash 后连续运行两次，均返回状态码 `0` 并输出：

```text
GREEN recognized-live-hash=1655f96aad74ad3fd074d08a2c38fe4253ba120ed8937996f4deb89abccc2e41
```

另外使用未列入 `knownSha256Hashes` 的 64 个 `0` 作为负例，`contains`
返回非零，确认未知内容仍会被阻断。修复后的
`nix fmt -- --check .`、`nix flake check` 与 macOS system build
均返回状态码 `0`；生成 `/etc/shells` 的 SHA-256 仍为
`66316f32567477d6fb6305706e2130bd22eb3e8972f3ce4e3fca849a04f28823`。

新的 activation 必须在执行前满足：

- 针对当前 build 运行上述只读 hash preflight，结果为 `GREEN`；
- 生成文件包含 `/run/current-system/sw/bin/fish`，不包含
  `/opt/homebrew/bin/fish`；
- 维护者针对包含精确 hash 例外的 commit 重新批准。

## 7. 人工 activation 清单

1. 审阅 nix-config PR #27 与 dotfiles PR #3，记录待激活 commit 和当前 generation。
2. 确认 Ghostty、WezTerm、Fish、Zsh、Atuin、mise 与重要可变状态具备可用备份或可回滚来源。
3. 对待激活 Home Manager generation 的所有 `home-files` 执行 live
   regular-file 冲突扫描；本次确认
   `~/.zshrc`、`~/.zprofile`、`~/.zshenv` 与
   `~/Library/Application Support/lazygit/config.yml` 是待备份冲突。
   另将旧 `~/.wezterm.lua` 移入同一备份，避免它优先遮蔽新的
   `~/.config/wezterm/wezterm.lua`；它不是 Home Manager link collision。
4. 关闭 Ghostty 与 WezTerm，避免旧进程掩盖新配置。
5. 由维护者针对精确 commit 批准并执行 nix-darwin activation。
6. 确认 `/etc/shells` 是指向 `/etc/static/shells` 的链接，内容包含
   `/run/current-system/sw/bin/fish`，且
   `/etc/shells.before-nix-darwin` 的 hash 与诊断记录一致。
7. 确认账户 `UserShell` 仍是 Nix Fish，新开 Ghostty 正常进入 Fish；
   不再次执行 `chsh`，也不要把管理员账户加入 `users.knownUsers`。
8. 从 `~/Applications/Home Manager Apps` 打开 Ghostty 与 WezTerm，分别验收两套支持环境。
9. 验证快捷键、主题、字体、Atuin、fzf、zoxide、lazygit、pay-respects、direnv、mise 与 pnpm。
10. 确认 OrbStack 与 PostgreSQL 仍正常，Rust/Haskell 数据目录未删除。
11. 完成 Nix 应用验收后，再单独批准定向执行 `brew uninstall --cask ghostty wezterm`。
12. 清理后再次确认 `/Applications` 不再残留 Homebrew 终端应用，Nix 应用仍可正常启动。

## 8. 回滚

1. 切回 activation 前的 nix-darwin generation，恢复上一代 Home Manager
   配置。上一代不管理 `/etc/shells`，回滚可能删除指向 `/etc/static` 的
   stale link，但不会自动恢复 `.before-nix-darwin` 备份。
2. 若回滚后 `/etc/shells` 缺失，先确认
   `/etc/shells.before-nix-darwin` 是 UID:GID `0:0`、mode `0644` 的
   普通文件，且 SHA-256 精确为
   `1655f96aad74ad3fd074d08a2c38fe4253ba120ed8937996f4deb89abccc2e41`。
   只有在 `/etc/shells` 仍缺失且维护者批准恢复时，才把该备份移回
   `/etc/shells`；不得覆盖任何未知的新文件或链接。
3. 若决定完整恢复旧登录 Shell，再单独批准并执行
   `chsh -s /opt/homebrew/bin/fish sayori`；不要把此前的批准自动扩展到
   新的账户修改。
4. 若 Nix 应用不可用，在未卸载 Homebrew cask 时直接从原应用回退；
   已卸载时按 activation 前版本重新安装。
5. dotfiles handoff 需在其仓库单独 revert，确认所有权恢复后才允许
   chezmoi 重新部署目标。
6. 不通过删除 Atuin、mise、Shell history、终端状态、OrbStack 或
   PostgreSQL 数据来“修复”声明问题。
