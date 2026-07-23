# Fish、Oh My Pi 与 mise 紧急修复记录

本文记录 Issue [#28](https://github.com/sayoriqwq/nix-config/issues/28) 的故障证据、所有权决策、离线验证、人工 activation 清单与回滚步骤。本文不授权 activation、Homebrew cleanup、删除可变数据或合并 Pull Request。

## 1. 故障与根因证据

- 采集日期：2026-07-23。
- live `~/.config/fish/config.fish` 是 7 行普通文件，不是 Home Manager 链接。
- 当前 Home Manager generation 中仍有 115 行完整 Fish 配置。
- live 文件只激活 Homebrew mise 并加入 `~/.bun/bin`，因此没有加载 Starship、zoxide、FZF、Atuin、direnv、eza aliases 与 Home Manager session PATH 等声明。
- `bun` 解析到 mise 的 Bun 1.3.14，`node` 解析到 mise 的 Node 25.8.1。
- `omp` 解析到 Bun global install，版本为 17.0.7；其入口要求 Bun `>=1.3.14`。
- 锁定 Nixpkgs 的 Bun 是 1.3.13，不能作为 OMP 17.0.7 的兼容运行时。

故障不是 Home Manager generation 损坏，而是 live target 被普通文件覆盖。修复必须恢复声明所有权，不能继续直接编辑 live 文件。

## 2. 第一性与所有权决策

mise 的核心职责是按全局、目录和项目切换语言运行时版本，不是单纯安装一个全局 Node/Bun。最终所有权如下：

| 目标 | 所有者 | 边界 |
| --- | --- | --- |
| mise 程序 | Home Manager `programs.mise` | Nix 安装并固定版本 |
| Fish activation | Home Manager `programs.mise.enableFishIntegration` | 使用 Nix Store 中的 mise 绝对路径 |
| 稳定默认工具 | nix-config 的 `mise/conf.d/10-nix-defaults.toml` | 默认 Node/Bun 为 `latest` |
| 全局个人选择 | 可写 `~/.config/mise/config.toml` | 保留 `mise use -g` |
| 项目工具版本 | 各项目的 `mise.toml` | 应随项目提交 |
| 项目个人覆盖 | 各项目的 `mise.local.toml` | 不提交 |
| 已安装运行时、cache、state | mise 可变数据目录 | 不进入 Git/Nix Store |
| Oh My Pi 程序 | Nix package | 使用官方独立二进制，不依赖 mise/Bun |
| `~/.omp` 配置、会话与登录态 | 本机可变数据 | 本 issue 不接管 |

Home Manager 不使用 `programs.mise.globalConfig` 占用 `~/.config/mise/config.toml`，因为只读 Store 链接会阻止 `mise use -g`。稳定默认值改放在 mise 原生支持的 `conf.d` 片段中，用户全局配置可以覆盖它。

direnv/nix-direnv 继续负责 Nix dev shell 与项目环境变量，mise 负责需要快速切换的语言运行时。同一项目不得让两者重复管理同一个 Node/Bun。

## 3. Oh My Pi 包来源

- 固定版本：17.0.8。
- 上游：[can1357/oh-my-pi v17.0.8](https://github.com/can1357/oh-my-pi/releases/tag/v17.0.8)。
- 资产：`omp-darwin-arm64`。
- 上游资产 SHA-256：`72d81812230b86fcb170d2737be01738e7a9a4afcd1f48019194bf72034dc9c9`。
- Nix SRI：`sha256-ctgYEiMLhvyxcNJze+AXOOeppK/NH0gBkZS/cgNNyck=`。

下载资产的实际 hash 与上游发布 hash 一致。该二进制在仅包含 `/usr/bin:/bin` 的隔离 PATH 下执行 `omp --version`，输出 `omp/17.0.8`，证明启动不依赖 mise、Bun 或 Node。

当前 package 只声明已经验证的 `aarch64-darwin`。其他平台有上游资产，但应在对应主机取得运行证据后再扩展 `meta.platforms` 和 source 映射。

## 4. 声明式修复

- `programs.mise` 由共享 Home Manager 层启用。
- Fish integration 由 Home Manager 生成，不在 `config.fish` 中手写 Homebrew 路径。
- `mise/conf.d/10-nix-defaults.toml` 声明 Node/Bun 的默认 channel。
- Darwin 用户层安装独立的 OMP Nix package。
- 生成配置不加入 `~/.bun/bin`，因此 Nix OMP 是目标入口。
- Homebrew mise 与现有 mise runtime 暂时保留，直到新 generation 实机验收通过。

## 5. 人工 activation 清单

1. 审阅 Draft PR，记录目标 commit、当前 generation 和上一代 generation。
2. 为 live `~/.config/fish/config.fish` 创建权限受限备份，记录 hash。
3. 退出除当前操作终端外的 Ghostty/Fish 会话。
4. 把 live regular file 移入备份目录；不要直接删除，不要改 Fish history、Atuin 数据或 `~/.omp`。
5. 针对目标 commit 明确批准后，由维护者执行 macOS activation。
6. 新开 Ghostty/Fish，确认 `config.fish` 是 Home Manager 链接。
7. 验证 prompt、zoxide、FZF、Atuin、direnv、eza aliases 与 Home Manager PATH。
8. 验证 `command -s mise` 指向 Nix profile，`mise doctor` 正常。
9. 在临时项目中使用 `mise use node@24` 验证目录切换；退出目录后确认恢复全局版本。
10. 验证 `command -s omp` 指向 Nix profile，`omp --version` 为 17.0.8，并确认既有 `~/.omp` 登录态与配置可用。
11. 验收通过后，另行批准卸载 Homebrew mise 和 Bun global OMP；mise 下载的 Node/Bun runtime 不删除。

## 6. 回滚

1. 优先回滚上一代 nix-darwin/Home Manager generation。
2. 从权限受限备份恢复原 live `config.fish`。
3. Homebrew mise、旧 Bun global OMP 与 mise runtime 在验收前都保留，因此回滚不需要重新下载。
4. 不删除 `~/.local/share/mise`、Fish history、Atuin 数据、`~/.omp` 或其他可变数据。

## 7. 验收约束

离线阶段运行：

```fish
nix fmt -- --check .
nix flake check
nix build .#darwinConfigurations.macbook.system --no-link
```

还必须检查生成 Fish 配置包含 Nix mise integration、不包含 Homebrew mise 和 `~/.bun/bin`，并在未 activation 的 generation 中执行 OMP 版本探针。

## 8. 离线验证结果

以下命令均返回 `0`：

```fish
nix fmt -- --check .
nix flake check
nix build .#darwinConfigurations.macbook.system --no-link
```

构建结果：

- macOS system：`/nix/store/iqbqi77ypcnzk9z73vfwwymkzwn1ga52-darwin-system-26.05.c3e90c8`；
- Home Manager generation：`/nix/store/mqbxlx8cbrgmdp9h06pdbrlamk8wz7nb-home-manager-generation`；
- mise：2026.5.12；
- Oh My Pi：17.0.8。

生成物检查确认：

- `fish -n` 通过生成的 `config.fish`；
- Fish integration 使用 Nix Store 中 mise 的绝对路径；
- 生成配置不包含 `/opt/homebrew/.../mise` 或 `~/.bun/bin`；
- `mise/conf.d/10-nix-defaults.toml` 包含 Node/Bun 默认 channel；
- Home Manager generation 没有创建 `mise/config.toml`；
- OMP 在仅含 `/usr/bin:/bin` 的隔离 PATH 下输出 `omp/17.0.8`；
- 使用 generation 配置的可写临时副本启动交互式 Fish 后，Starship、zoxide、FZF/Atuin、direnv、eza、mise 与 OMP 均可解析，mise 与 OMP 均来自新 generation 的 `home-path/bin`。

离线阶段的原始 live 反馈环仍报告 `config.fish` 不是 Home Manager 链接；后续人工关卡完成后的最终结果见下一节。

## 9. 实机 activation 与验收

维护者于 2026-07-23 批准针对 commit `2622b96` 执行 activation，并明确确认原 7 行 live `config.fish` 不需要备份。Agent 在复核 commit、文件类型与行数后删除该精确 regular file，并执行：

```fish
sudo -H /run/current-system/sw/bin/darwin-rebuild switch \
  --flake "/Users/sayori/Desktop/nix-config#macbook"
```

命令返回 `0`。实机验收结果：

- `~/.config/fish/config.fish` 已恢复为指向 Nix Store 的 Home Manager 链接；
- 全新交互式 Fish 能加载 Starship、zoxide、FZF、Atuin、direnv、eza 与声明式 PATH；
- Atuin 的 `Ctrl+R`、`Ctrl+Up` 绑定存在；
- mise 2026.5.12 来自 `/etc/profiles/per-user/sayori/bin/mise`，Fish wrapper 调用 Nix Store 中的 mise；
- OMP 17.0.8 来自 Nix profile；
- Bun 1.3.14 继续由 mise 管理；
- 增量安装 Node 26.5.0 后，原 Node 25.8.1 仍保留；
- 临时项目的 `mise.toml` 能把 Node 切换到 25.8.1，离开项目后全局恢复 26.5.0；
- `mise doctor` 报告 `No problems found`。

`mise doctor` 仍提示当前锁定的 mise 不是上游最新版，以及 mise tool paths 排在 Nix profile 与 `~/.local/bin` 之后。当前声明禁止 Nix 与 mise 重复管理 Node/Bun，实机切换也已通过，因此保留上游默认 `activate_aggressive = false`，不为消除非阻塞 warning 改变 PATH 语义。

Homebrew mise、Bun global OMP 和 mise 下载的运行时仍保留。它们的清理需要单独批准，不属于本次 activation。
