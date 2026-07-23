# mise 与 Node/Bun 所有权

本文记录 Issue #30 的终态边界、迁移前事实、验收与精确清理范围。目标不是让 Nix 接管语言运行时，而是由 Nix 提供 mise，由 mise 唯一管理 Node/Bun。

## 1. 终态

| 对象 | 唯一所有者 | 声明或数据位置 |
| --- | --- | --- |
| mise 本体 | Nix/Home Manager | 稳定 nixpkgs 与 `programs.mise` |
| mise 共享默认与 PATH 策略 | Nix/Home Manager | `~/.config/mise/conf.d/10-nix-defaults.toml` 的生成链接 |
| Node/Bun 全局默认与已安装版本 | mise | `~/.config/mise/config.toml`、`~/.local/share/mise` |
| 项目版本 | 项目 | 项目提交的 `mise.toml` |
| 项目个人覆盖 | 开发者 | 不提交的 `mise.local.toml` |
| Oh My Pi 本体 | Nix/Home Manager | `packages/oh-my-pi/default.nix` |
| mise runtime、cache、state | 可变数据 | 保留在用户可写目录，不提交仓库 |

Home Manager 求值包含硬约束：如果 `home.packages` 直接加入 `nodejs`、`nodejs-slim` 或 `bun`，求值必须失败。Nix 可以作为 mise 本体的安装来源，但未来不得直接安装 Node/Bun。

## 2. 迁移前证据

采集日期：2026-07-23。

- 当前 Fish 中的 `mise` wrapper 仍固定调用 Homebrew mise `2026.3.9`；Nix profile 同时存在 mise，形成重复入口。
- Node 当前解析到 `~/.local/share/mise/installs/node/26.5.0/bin/node`。
- Bun 当前解析到 `~/.local/share/mise/installs/bun/1.3.14/bin/bun`。
- mise 保留 Node `20.19.0`、`22.23.1`、`25.8.1`、`26.5.0` 和 Bun `1.3.11`、`1.3.14`；这些版本不得在 cleanup 中删除。
- `omp` 当前优先解析到 Nix profile，但 Bun global 仍保留 `@oh-my-pi/pi-coding-agent@17.0.7`，形成重复入口。

## 3. 本次声明

- mise 直接取自仓库现有的稳定 nixpkgs，当前版本为 `2026.5.12`；不为追逐上游版本引入 unstable input 或自制 mise 派生。
- 共享默认声明 `node = "latest"` 与 `bun = "latest"`；实际下载、安装与版本切换仍由 mise 执行。
- `activate_aggressive = true` 让 mise 在 shell activation 时确定地把当前 runtime 路径放到其他同名命令之前，消除 tool-path warning。
- Fish integration 由 Home Manager 生成；激活后 `mise` 必须来自 Nix profile，Node/Bun 必须来自 mise 数据目录。
- OMP 继续由 Nix 独立安装，不依赖 Bun global package。

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

## 5. 精确 cleanup 关卡

只有上述实机验收通过并再次获得明确批准后，才允许清理：

```fish
brew uninstall mise
bun remove --global @oh-my-pi/pi-coding-agent
```

cleanup 后再次执行第 4 节全部检查，并确认 `type -a mise` 不再包含 Homebrew 路径、`type -a omp` 不再包含 `~/.bun/bin/omp`。

严禁删除：

- `~/.local/share/mise/**`
- `~/.config/mise/config.toml`
- 任何项目 `mise.toml` 或 `mise.local.toml`
- `~/.omp/**`

## 6. 回滚

激活异常时切回上一代 nix-darwin/Home Manager generation；这会恢复旧 shell integration，不触碰 mise runtime/data。

若 cleanup 后需要临时恢复旧入口，可以重新执行 `brew install mise`；OMP 的回滚优先切回上一代 Nix generation，只有 Nix OMP 不可用时才重新通过 Bun global 安装。回滚不会改变 Node/Bun 的 mise 所有权决策。
