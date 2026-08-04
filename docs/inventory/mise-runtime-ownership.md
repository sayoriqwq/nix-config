# mise 与语言运行时所有权

本文记录 Issue #30 与 #43 的终态边界、迁移前事实、验收与精确清理范围；Issue #67
补充 AI CLI 边界，Issue #93 最终清理停用 runtime 与可变的全局默认配置。它们都不
改变 mise 的运行时所有权。
目标不是让 Nix 接管语言运行时，而是由 Nix 提供 mise，由 mise 管理 Node/Bun
及桌面工作站的 Erlang/Elixir。

## 1. 终态

| 对象 | 唯一所有者 | 声明或数据位置 |
| --- | --- | --- |
| mise 本体 | Nix/Home Manager | 稳定 nixpkgs 与 `programs.mise` |
| mise 共享默认与 PATH 策略 | Nix/Home Manager | `~/.config/mise/conf.d/10-nix-defaults.toml` 的生成链接 |
| Node/Bun 全局默认 | Nix/Home Manager + mise | `~/.config/mise/conf.d/10-nix-defaults.toml` 的生成链接；mise 解析 `latest` |
| Node/Bun 已安装版本 | mise 可变数据 | `~/.local/share/mise` |
| 桌面 Erlang/Elixir 版本选择 | Nix/Home Manager + mise | `~/.config/mise/conf.d/20-desktop-runtimes.toml` 与 `~/.local/share/mise` |
| 项目版本 | 项目 | 项目提交的 `mise.toml` |
| 项目个人覆盖 | 开发者 | 不提交的 `mise.local.toml` |
| Oh My Pi（`omp`） | Nix/Home Manager | 官方 `darwin-arm64` 固定发布物 `17.2.4`；`~/.omp` 状态保持外部可写 |
| mise runtime、cache、state | 可变数据 | 保留在用户可写目录，不提交仓库 |

Home Manager 求值包含硬约束：如果 `home.packages` 直接加入 `nodejs`、
`nodejs-slim`、`bun`、`erlang` 或 `elixir`，求值必须失败。Nix 可以作为 mise
本体的安装来源，但不得直接安装这些由 mise 拥有的运行时。

Issue #67 的四个 AI CLI（`codex`、`claude`、`agy`、`omp`）不由 mise 提供；它们由
macbook 的 Nix/Home Manager capability 统一声明。版本、客户端自更新策略、可变状态
和旧副本清理关卡见 [`macOS AI CLI 所有权`](macos-ai-cli-ownership.md)。

## 2. 迁移前证据（历史）

采集日期：2026-07-23。

- 当前 Fish 中的 `mise` wrapper 仍固定调用 Homebrew mise `2026.3.9`；Nix profile 同时存在 mise，形成重复入口。
- Node 当前解析到 `~/.local/share/mise/installs/node/26.5.0/bin/node`。
- Bun 当前解析到 `~/.local/share/mise/installs/bun/1.3.14/bin/bun`。
- mise 当时保留 Node `20.19.0`、`22.23.1`、`25.8.1`、`26.5.0` 和 Bun `1.3.11`、`1.3.14`；#30 的 cleanup 不删除这些版本，后由 #93 重新盘点并批准清理停用版本。
- 历史记录中的 `omp` 曾优先解析到 Nix profile，而 Bun global 曾保留
  `@oh-my-pi/pi-coding-agent@17.0.7`；该 Bun global 已按 #30 精确删除，不是当前
  duplicate，也不在本轮清理目标中。
- 停用的 mise Node `25.8.1` 树仍记录有 `@openai/codex@0.144.4` 与
  `oh-my-codex@0.14.2`；本轮只把前者列为待批准的精确清理目标，后者明确不清理。

## 3. 本次声明

- mise 直接取自仓库现有的稳定 nixpkgs，当前版本为 `2026.5.12`；不为追逐上游版本引入 unstable input 或自制 mise 派生。
- 共享默认声明 `node = "latest"` 与 `bun = "latest"`；实际下载、安装与版本切换仍由 mise 执行。
- `activate_aggressive = true` 让 mise 在 shell activation 时确定地把当前 runtime 路径放到其他同名命令之前，消除 tool-path warning。
- Fish integration 由 Home Manager 生成；激活后 `mise` 必须来自 Nix profile，Node/Bun 必须来自 mise 数据目录。
- `omp`（Oh My Pi）由 Nix/Home Manager 固定官方 `darwin-arm64` 发布物 `17.2.4`，
  不依赖 mise global package；`~/.omp` 及客户端登录态、配置、session、history、
  skills/hooks、缓存和数据库继续保持可写外部状态。

### 3.1 桌面 Erlang/Elixir

Issue #43 在 desktop/workstation 层精确声明：

```toml
[tools]
erlang = "29.0.3"
elixir = "1.20.2-otp-29"
```

该文件不进入 `modules/home/common/`，因此 headless server 不会继承 Erlang/Elixir。
版本来自 mise core backend；锁定版本均已通过 `mise ls-remote` 确认存在。

Home Manager activation 只安装声明文件，不下载或编译 runtime。mise 当前
`auto_install = true`，缺失版本可能在 `mise x`、mise task 或 command-not-found
时自动安装。为避免 activation 后第一次执行 `elixir` 时产生不可预测等待，Agent
在 activation 前显式运行 `mise install erlang@29.0.3 elixir@1.20.2-otp-29`，
并验证 runtime；该操作只写入 `~/.local/share/mise` 可变状态。

迁移前本机 Homebrew 提供 Erlang 28.5 与 Elixir 1.19.5；mise 已保留相同旧版本的
runtime。Homebrew 副本在新版本通过真实项目验收前继续作为回退，不在 #43 清理。

2026-07-27 首次显式预装因 GitHub 网络连接中断而失败；网络恢复后使用同一精确
版本命令重试成功。`mise x` 已验证 Erlang/OTP 29（ERTS 17.0.3）与 Elixir 1.20.2
（编译目标 OTP 29）可以共同运行。由于 Home Manager 声明尚未 activation，mise
正确提示 runtime 已安装但尚未由配置激活；当前默认 PATH 仍保持迁移前状态。

## 4. 激活后验收

激活必须针对已审阅 commit 获得明确批准。打开全新 Fish 后执行：

```fish
mise --version
mise doctor
command -s mise
command -s node
command -s bun
command -s omp
node --version
bun --version
omp --version
```

通过条件：

- mise 为锁定稳定 nixpkgs 提供的版本，且来自 `/etc/profiles/per-user/sayori/bin/mise`；
- `mise doctor` 没有 problem、PATH 冲突或其他可避免 warning；上游版本更新提示不视为环境冲突，由后续 flake input 更新消除；
- Node/Bun 分别来自 `~/.local/share/mise/installs/node/` 与 `~/.local/share/mise/installs/bun/`；
- OMP 来自 Nix profile；
- 全局 Node/Bun 为 mise `latest` 的当前解析版本；
- 在临时目录写入项目级版本选择后，新 Fish 能切换到已安装旧版本；离开目录后恢复全局版本。

## 5. 精确 cleanup 关卡（#30/#43 历史记录）

以下命令记录 #30/#43 已批准的旧入口 cleanup，不是 #67 activation 的操作指令：

```fish
brew uninstall mise
bun remove --global @oh-my-pi/pi-coding-agent
```

cleanup 后再次执行第 4 节全部检查，并确认 `type -a mise` 不再包含 Homebrew 路径、`type -a omp` 不再包含 `~/.bun/bin/omp`。

Issue #67 当时把 Homebrew Claude 2.1.153、`~/.local/bin/agy` 1.0.8 和停用 Node
25.8.1 树中的 `@openai/codex@0.144.4` 留给后续人工关卡。#93 在重新核对真实路径、
版本和消费者后批准并完成清理；详情见 [`macOS AI CLI 所有权`](macos-ai-cli-ownership.md)。

严禁删除：

- 当前使用中的 `~/.local/share/mise/**`
- `~/.config/mise/conf.d/10-nix-defaults.toml` 与 `20-desktop-runtimes.toml` 生成链接
- 任何项目 `mise.toml` 或 `mise.local.toml`
- `~/.omp/**`

## 6. 回滚

激活异常时切回上一代 nix-darwin/Home Manager generation；这会恢复旧 shell integration，不触碰 mise runtime/data。

若 cleanup 后需要临时恢复旧入口，可以重新执行 `brew install mise`；历史 OMP 的回滚
优先切回上一代 Nix generation，只有旧 generation 不可用时才重新通过 Bun global 安装。
回滚不会改变 Node/Bun 的 mise 所有权决策，也不会自动恢复 #67 的 AI CLI duplicate。

## 7. Activation 与 cleanup 记录

维护者批准 commit `b8dcdb7` 后，于 2026-07-23 完成 macOS activation。`darwin-rebuild switch` 退出状态为 0，新 system 为 `/nix/store/vn39732i8ixbx2qvwwv2csyc5jrcihby-darwin-system-26.05.c3e90c8`。

全新交互式 Fish 验收确认：

- mise 来自 Nix Store，版本为稳定 nixpkgs 提供的 `2026.5.12`；
- Node/Bun 全局版本分别为 `26.5.0`、`1.3.14`，均来自 mise 数据目录；
- 临时项目成功切换到已安装的 Node `25.8.1`、Bun `1.3.11`，离开项目后恢复全局版本；
- OMP 来自 Nix profile，版本为 `17.0.8`；
- `mise doctor` 无 problem，仅显示维护者已接受的上游版本更新提示；
- `~/.local/share/mise`、`~/.config/mise/config.toml` 与 `~/.omp` 均保持完整。

维护者随后单独批准 cleanup。Bun global `@oh-my-pi/pi-coding-agent@17.0.7` 与 Homebrew mise `2026.3.9` 已精确删除。Homebrew 在卸载 mise 时自动把不再被任何 formula 需要的依赖 `usage 3.0.0` 一并 autoremove；当前没有独立 `usage` 命令。

Home Manager 的 mise Fish integration 按上游默认只在交互式 Shell 中 activation。Ghostty/Fish 终端及其子进程会获得 Node/Bun PATH；独立启动的非交互式 `fish -lc` 不自动注入 runtime PATH，脚本或自动化应显式使用 `mise exec -- <command>`。本 Issue 不额外改变该默认语义。

### 7.1 Issue #93 最终收口

2026-08-03 的重新盘点确认，全局 Node/Bun 默认已经由 Home Manager 生成的
`10-nix-defaults.toml` 声明，不需要第二份可变 `~/.config/mise/config.toml`。维护者
批准后完成以下定向动作：

- 删除空的可变 `config.toml`，保留两个 Home Manager 生成的 `conf.d` 链接；
- 删除停用的 Node `20.19.0`、`22.23.1`、`25.8.1`、Bun `1.3.11`、Erlang `28.5`
  与 Elixir `1.19.5-otp-28`；
- 删除 Node 26 npm global 中的重复 `pnpm`，并保留 mise 独立管理的 pnpm；
- 删除只为 Bun global 保留的 `~/.bun/bin` PATH 注入及孤立 global 包树。

终态只保留 Node `26.5.0`、Bun `1.3.14`、Erlang `29.0.3`、Elixir
`1.20.2-otp-29` 与 pnpm `11.16.0`。`mise ls --json` 的 source 全部指向两个
Home Manager `conf.d` 声明；项目级 `mise.toml`、runtime cache 和当前 runtime 均未
被批量扫描或删除。

## 8. Erlang/Elixir 验收与回滚

Issue #43 activation 后，在全新交互式 Fish 中验证：

```fish
mise current
erl -noshell -eval 'erlang:display(erlang:system_info(otp_release)), halt().'
elixir --version
mix --version
```

Symphony checkout 在本次只读盘点时未出现在 Spotlight 或现有工作目录索引中，
不得猜测路径。项目重新出现后，应执行不改动锁文件的最窄测试并补充验收记录。

generation 回滚会撤销 desktop 版本选择，但不会重新下载 #93 已删除的停用 runtime。
Homebrew Erlang/Elixir 已在既有迁移验收后移除；如需旧版本，必须由项目声明或新的窄
维护 Issue 重新安装，不能恢复成未声明的全局默认。
